
module core (                       //Don't modify interface
	input         i_clk,
	input         i_rst_n,
	input         i_op_valid,
	input  [ 3:0] i_op_mode,
    output        o_op_ready,
	input         i_in_valid,
	input  [ 7:0] i_in_data,
	output        o_in_ready,
	output        o_out_valid,
	output [13:0] o_out_data
);
//params for FSM//
localparam  S_IDLE				 = 4'd0,		// Reset 
			S_READY				 = 4'd1,
			S_FETCHING			 = 4'd2,
			S_LOADING			 = 4'd3,
			S_DISPLAY			 = 4'd4,
			S_SHIFT_AND_DEPTH	 = 4'd5,
			S_CONV				 = 4'd6,
			S_BUF0				 = 4'd7,
			S_BUF1				 = 4'd8,
			S_HARR				 = 4'd9,
			S_HARR_BUF			 = 4'd10,
			S_HARR_OP			 = 4'd11,
			S_HARR_BUF2			 = 4'd12,
			S_MEDIAN			 = 4'd13,
			S_MEDIAN_OP			 = 4'd14,
			S_MEDIAN_BUF		=  4'd15;

//params for opmode//
localparam  LOAD_IFMAP	 	= 4'd0,
			ORIGIN_RSHIFT 	= 4'd1,
			ORIGIN_LSHIFT 	= 4'd2,
			ORIGIN_USHIFT	= 4'd3,
			ORIGIN_DSHIFT	= 4'd4,
			REDUCE_DEPTH 	= 4'd5,
			INCRESE_DEPTH 	= 4'd6,
			OUTPUT_DISPLAY 	= 4'd7,
			CONVOLUTION 	= 4'd8,
			MEDIAN_FILTER 	= 4'd9,
			HAAR_WAVELET	= 4'd10;

function [7:0] median;
	input [7:0] data_1;
	input [7:0] data_2;
	input [7:0] data_3;
	begin
		if (data_1 <= data_3 && data_1 >= data_2) median = data_1;
		else if (data_1 <= data_2 && data_1 >= data_3) median = data_1;
		else if (data_2 <= data_1 && data_2 >= data_3) median = data_2;
		else if (data_2 <= data_3 && data_2 >= data_1) median = data_2;
		else if (data_3 <= data_2 && data_3 >= data_1) median = data_3;
		else if (data_3 <= data_1 && data_3 >= data_2) median = data_3;
	end
endfunction

function [7:0] max;
	input [7:0] data_1;
	input [7:0] data_2;
	input [7:0] data_3;
	begin
		if (data_1 >= data_3 && data_1 >= data_2) max = data_1;
		else if (data_1 >= data_2 && data_1 >= data_3) max = data_1;
		else if (data_2 >= data_1 && data_2 >= data_3) max = data_2;
		else if (data_2 >= data_3 && data_2 >= data_1) max = data_2;
		else if (data_3 >= data_2 && data_3 >= data_1) max = data_3;
		else if (data_3 >= data_1 && data_3 >= data_2) max = data_3;
	end
endfunction

function [7:0] min;
	input [7:0] data_1;
	input [7:0] data_2;
	input [7:0] data_3;
	begin
		if (data_1 <= data_3 && data_1 <= data_2) min = data_1;
		else if (data_1 <= data_2 && data_1 <= data_3) min = data_1;
		else if (data_2 <= data_1 && data_2 <= data_3) min = data_2;
		else if (data_2 <= data_3 && data_2 <= data_1) min = data_2;
		else if (data_3 <= data_2 && data_3 <= data_1) min = data_3;
		else if (data_3 <= data_1 && data_3 <= data_2) min = data_3;
	end
endfunction

function [7:0] median_2;
	input [7:0] data_11;
	input [7:0] data_12;
	input [7:0] data_13;
	input [7:0] data_21;
	input [7:0] data_22;
	input [7:0] data_23;
	input [7:0] data_31;
	input [7:0] data_32;
	input [7:0] data_33;
	reg [7:0] max1, max2, max3;
	reg [7:0] min1, min2, min3;
	reg [7:0] med1, med2, med3;
	reg [7:0] tem1, tem2, tem3;
	begin
		max1 = max(data_11, data_12, data_13);
		med1 = median(data_11, data_12, data_13);
		min1 = min(data_11, data_12, data_13);
		max2 = max(data_21, data_22, data_23);
		med2 = median(data_21, data_22, data_23);
		min2 = min(data_21, data_22, data_23);
		max3 = max(data_31, data_32, data_33);
		med3 = median(data_31, data_32, data_33);
		min3 = min(data_31, data_32, data_33);
		tem1 = min(max1, max2, max3);
		tem2 = median(med1, med2, med3);
		tem3 = max(min1, min2, min3);
		median_2 = median(tem1, tem2, tem3);
	end
endfunction
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //
reg [3:0] state_r, state_w;
reg [3:0] op_mode_r, op_mode_w;
reg o_in_ready_reg, o_out_valid_reg;

//SRAM LOAD and DISPLAY//
reg [10:0] counter;
wire [10:0] counter_nxt = (state_r == S_LOADING || state_r == S_DISPLAY || state_r == S_CONV || state_r == S_HARR || state_r == S_HARR_OP || state_r == S_MEDIAN || state_r == S_MEDIAN_OP) ? counter+1 : 0;
wire [7:0] sram_data_in = (i_in_valid) ? i_in_data : 0;
reg [1:0] sram_sel;
reg [8:0] sram_addr [0:3];
wire [7:0] sram_q [0:3];
wire sram_wen [0:3];
reg [10:0] display_addr;
reg [1:0] display_sel; // remember which q should be display
wire [13:0] display_output = {6'd0, sram_q[display_sel]};
// ORIGIN SHIFT //
reg [2:0] origin_row, origin_col;
reg [2:0] origin_row_nxt, origin_col_nxt;

// CHANNEL DEPTH //
reg [5:0] channel_depth, channel_depth_nxt;
localparam 	DEPTH_8	 = 6'd8,
			DEPTH_16 = 6'd16,
			DEPTH_32 = 6'd32;

//CONV//
wire [2:0] conv_row [0:3];
wire [2:0] conv_col [0:3];
wire [1:0] conv_sel	[0:3];

reg [7:0] conv_raw_data [0:15];
reg [17:0] conv_partial_sum [0:3];
reg [13:0] conv_round [0:3];
reg conv_out_valid_3, conv_out_valid_2, conv_out_valid_1, conv_out_valid_0; 
reg [1:0] conv_counter;
wire [13:0] conv_output = conv_round[conv_counter];

//HARR//
reg [7:0] harr_raw_data [0:3];
reg [14:0] harr_partial_sum [0:3][0:3];
wire [13:0] harr_output = harr_partial_sum[counter[1:0]][counter[3:2]][14:1] + harr_partial_sum[counter[1:0]][counter[3:2]][0];
//MEDIAN//
reg [7:0] median_result [0:3][0:3];
wire [13:0] median_output = {6'd0, median_result[counter[1:0]][counter[3:2]]};
// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
assign o_op_ready = (state_r == S_READY);
assign o_out_data = (op_mode_r == OUTPUT_DISPLAY) 	? display_output : (
					(op_mode_r == CONVOLUTION)	? conv_output:(
					(op_mode_r == HAAR_WAVELET) ? harr_output : (
					(op_mode_r == MEDIAN_FILTER) ? median_output : 0
					)
					));
assign o_out_valid = o_out_valid_reg;
assign o_in_ready = o_in_ready_reg;

//SRAM LOAD and DISPLAY//
assign sram_wen[0] = !((state_r == S_LOADING) && (sram_sel == 2'd0));
assign sram_wen[1] = !((state_r == S_LOADING) && (sram_sel == 2'd1));
assign sram_wen[2] = !((state_r == S_LOADING) && (sram_sel == 2'd2));
assign sram_wen[3] = !((state_r == S_LOADING) && (sram_sel == 2'd3));

//CONV//
//the coors of elements used in convolution are [origin-1:origin+2]
assign conv_row[0] = origin_row-1;
assign conv_row[1] = origin_row;
assign conv_row[2] = origin_row+1;
assign conv_row[3] = origin_row+2;

assign conv_col[0] = origin_col-1;
assign conv_col[1] = origin_col;
assign conv_col[2] = origin_col+1;
assign conv_col[3] = origin_col+2;


		// {sram_addr [8:0], sram_sel[1:0]} = 00000_000_000
		//									channel row col
assign conv_sel[0] = conv_col[0][1:0];
assign conv_sel[1] = conv_col[1][1:0];
assign conv_sel[2] = conv_col[2][1:0];
assign conv_sel[3] = conv_col[3][1:0];

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //
//FSM//
always @(*) begin
	state_w = state_r; // repeat for multi-cycle operations
	case (state_r)
		S_IDLE:state_w = S_READY;
		S_READY:state_w = S_FETCHING;
		S_FETCHING:begin
			if (i_op_mode == LOAD_IFMAP)
				state_w = S_LOADING;
			else if (i_op_mode == OUTPUT_DISPLAY) 
				state_w = S_DISPLAY;  //simple display
			else if (i_op_mode == CONVOLUTION)
				state_w = S_CONV;  //convolution display
			else if (i_op_mode == HAAR_WAVELET)
				state_w = S_HARR;
			else if (i_op_mode == MEDIAN_FILTER)
				state_w = S_MEDIAN;
			else state_w = S_SHIFT_AND_DEPTH; //one-cycle operations 
		end
		S_SHIFT_AND_DEPTH:state_w = S_READY;
		S_LOADING:if (counter == 11'd2047) state_w = S_IDLE;
		//TODO end display and end conv//
		S_DISPLAY:begin
			if (counter == ((channel_depth << 2) - 1)) //channel_depth * 4
				state_w = S_IDLE; 
		end
		S_CONV:begin
			if (counter == ((channel_depth << 2) - 1 + 3)) //channel_depth * 4
				state_w = S_BUF0; 
		end
		S_BUF0:state_w = S_BUF1;
		S_BUF1:state_w = S_IDLE;  
		S_HARR:begin
			if (counter ==  10)
				state_w = S_HARR_BUF; 
		end
		S_HARR_BUF:state_w = S_HARR_OP; 
		S_HARR_OP:begin
			if (counter ==  14)
				state_w = S_IDLE; 
		end
		S_MEDIAN:begin
			if (counter == ((4 * 4) - 1 + 3)) //channel_depth * 4
				state_w = S_MEDIAN_BUF; 
		end
		S_MEDIAN_BUF:state_w = S_MEDIAN_OP; 
		S_MEDIAN_OP:begin
			if (counter ==  14)
				state_w = S_IDLE; 
		end
	endcase
end

//update the opmode//
always @ (*) begin
	if (i_op_valid) op_mode_w = i_op_mode;
	else op_mode_w = op_mode_r;
end
integer i;
always @(*) begin
	sram_sel = counter[1:0]; // (#0, #4, #8...) => sram_0, (#1, #5, #9...) => sram_1...  // for parallel read 
	for (i=0; i < 4; i=i+1)
		sram_addr[i] = counter[10:2];

	//DISPLAY//
	display_addr = 0;
	if (state_r == S_DISPLAY) begin
		case (counter[1:0])
		// {sram_addr [8:0], sram_sel[1:0]} = 00000_000_000
		//									channel row col
			2'd0:display_addr = {counter[6:2], origin_row, origin_col};
			2'd1:display_addr = {counter[6:2], origin_row, origin_col}+1;
			2'd2:display_addr = {counter[6:2], origin_row, origin_col}+8;
			2'd3:display_addr = {counter[6:2], origin_row, origin_col}+9;
		endcase
		for (i=0; i<4; i=i+1)
			sram_addr[i] = display_addr[10:2];
		sram_sel = display_addr[1:0];
	end
	//CONV and median//
	else if (state_r == S_CONV || state_r == S_MEDIAN) begin // load 4 values per cycle parallelly
		case (counter[1:0])
		2'd0:begin
			sram_addr[conv_sel[0]] = {counter[6:2], conv_row[0], conv_col[0][2]};// {sram_addr [8:0], sram_sel[1:0]} = 00000_000_000
			sram_addr[conv_sel[1]] = {counter[6:2], conv_row[0], conv_col[1][2]};//	    							 channel row col
			sram_addr[conv_sel[2]] = {counter[6:2], conv_row[0], conv_col[2][2]};
			sram_addr[conv_sel[3]] = {counter[6:2], conv_row[0], conv_col[3][2]};
		end
		2'd1:begin
			sram_addr[conv_sel[0]] = {counter[6:2], conv_row[1], conv_col[0][2]};
			sram_addr[conv_sel[1]] = {counter[6:2], conv_row[1], conv_col[1][2]};
			sram_addr[conv_sel[2]] = {counter[6:2], conv_row[1], conv_col[2][2]};
			sram_addr[conv_sel[3]] = {counter[6:2], conv_row[1], conv_col[3][2]};
		end
		2'd2:begin
			sram_addr[conv_sel[0]] = {counter[6:2], conv_row[2], conv_col[0][2]};
			sram_addr[conv_sel[1]] = {counter[6:2], conv_row[2], conv_col[1][2]};
			sram_addr[conv_sel[2]] = {counter[6:2], conv_row[2], conv_col[2][2]};
			sram_addr[conv_sel[3]] = {counter[6:2], conv_row[2], conv_col[3][2]};
		end
		2'd3:begin
			sram_addr[conv_sel[0]] = {counter[6:2], conv_row[3], conv_col[0][2]};
			sram_addr[conv_sel[1]] = {counter[6:2], conv_row[3], conv_col[1][2]};
			sram_addr[conv_sel[2]] = {counter[6:2], conv_row[3], conv_col[2][2]};
			sram_addr[conv_sel[3]] = {counter[6:2], conv_row[3], conv_col[3][2]};
		end
		endcase
	end
	//HARR
	else if (state_r == S_HARR) begin
		case (counter[0])
		0: begin 
			sram_addr[conv_sel[1]] = {counter[5:1], conv_row[1], conv_col[1][2]};
			sram_addr[conv_sel[2]] = {counter[5:1], conv_row[1], conv_col[2][2]};
		end
		1: begin
			sram_addr[conv_sel[1]] = {counter[5:1], conv_row[2], conv_col[1][2]};
			sram_addr[conv_sel[2]] = {counter[5:1], conv_row[2], conv_col[2][2]};
		end
		endcase
	end
end

sram_512x8 sram_0 (.Q(sram_q[0]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen[0]), .A(sram_addr[0]), .D(sram_data_in));
sram_512x8 sram_1 (.Q(sram_q[1]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen[1]), .A(sram_addr[1]), .D(sram_data_in));
sram_512x8 sram_2 (.Q(sram_q[2]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen[2]), .A(sram_addr[2]), .D(sram_data_in));
sram_512x8 sram_3 (.Q(sram_q[3]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen[3]), .A(sram_addr[3]), .D(sram_data_in));


// ORIGIN SHIFT //
//	  col 0 1 2 3 4...
//	row 0 ---------
//		1 | | | | |
//		2 | | | | |
//		3 | | | | |
//		4 ---------
always @(*) begin
	origin_row_nxt = origin_row;
	origin_col_nxt = origin_col;
	if (state_r == S_SHIFT_AND_DEPTH) begin
		case (op_mode_r)
			ORIGIN_RSHIFT: if (origin_col!=6) begin
				origin_col_nxt = origin_col + 1;
			end  
			ORIGIN_LSHIFT: if (origin_col!=0) begin
				origin_col_nxt = origin_col - 1;
			end
			ORIGIN_USHIFT: if (origin_row!=0) begin
				origin_row_nxt = origin_row - 1;
			end
			ORIGIN_DSHIFT: if (origin_row!=6) begin
				origin_row_nxt = origin_row + 1;
			end
		endcase
	end
end

// CHANNEL DEPTH //

always @(*) begin
	if (state_r == S_SHIFT_AND_DEPTH) begin
		case (op_mode_r)
			REDUCE_DEPTH:begin // 8 -> 8, 16 -> 8, 32 -> 16
				if (channel_depth == DEPTH_32)
					channel_depth_nxt = DEPTH_16;
				else
					channel_depth_nxt = DEPTH_8;
			end 
			INCRESE_DEPTH:begin
				if (channel_depth == DEPTH_8)
					channel_depth_nxt = DEPTH_16;
				else
					channel_depth_nxt = DEPTH_32;
			end
			default: channel_depth_nxt = channel_depth;
		endcase
	end
	else channel_depth_nxt = channel_depth;
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //


//CONV calculation
	//read raw data for 1 channel
integer j;
always @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		for (j=0; j<16; j=j+1) begin
			conv_raw_data[j] <= 0;
		end
	end
	else if (state_r == S_FETCHING) begin
		for (j=0; j<16; j=j+1) begin
			conv_raw_data[j] <= 0;
		end
	end else begin
		if (state_r == S_CONV || state_r == S_MEDIAN) begin
			case(counter[1:0]) // conv_raw_data is 1 cycle behind sram_q 
			//handle zero padding
				2'd1: begin
					conv_raw_data[0] <= ((origin_row != 0) && (origin_col != 0)) ? sram_q[conv_sel[0]] : 0;
					conv_raw_data[1] <= (origin_row != 0)						 ? sram_q[conv_sel[1]] : 0;
					conv_raw_data[2] <= (origin_row != 0)						 ? sram_q[conv_sel[2]] : 0;
					conv_raw_data[3] <= ((origin_row != 0) && (origin_col != 6)) ? sram_q[conv_sel[3]] : 0;
				end
				2'd2:begin
					conv_raw_data[4] <= (origin_col != 0) ? sram_q[conv_sel[0]] : 0;
					conv_raw_data[5] <= sram_q[conv_sel[1]];
					conv_raw_data[6] <= sram_q[conv_sel[2]];
					conv_raw_data[7] <= (origin_col != 6) ? sram_q[conv_sel[3]] : 0;
				end
				2'd3:begin
					conv_raw_data[8] <= (origin_col != 0) ? sram_q[conv_sel[0]] : 0;
					conv_raw_data[9] <= sram_q[conv_sel[1]];
					conv_raw_data[10] <= sram_q[conv_sel[2]];
					conv_raw_data[11] <= (origin_col != 6) ? sram_q[conv_sel[3]] : 0;
				end
				2'd0:begin
					conv_raw_data[12] <= ((origin_row != 6) && (origin_col != 0)) ? sram_q[conv_sel[0]] : 0;
					conv_raw_data[13] <= (origin_row != 6)						 ? sram_q[conv_sel[1]] : 0;
					conv_raw_data[14] <= (origin_row != 6)						 ? sram_q[conv_sel[2]] : 0;
					conv_raw_data[15] <= ((origin_row != 6) && (origin_col != 6)) ? sram_q[conv_sel[3]] : 0;
				end
			endcase
		end
	end
end
	// partial sum accumulation
always @ (posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		for (j=0; j<4; j=j+1) begin
			conv_partial_sum[j] <= 0;
		end
	end else if (state_r == S_FETCHING) begin
		for (j=0; j<4; j=j+1) begin
			conv_partial_sum[j] <= 0;
		end
	end else begin
		if (state_r == S_CONV) begin
			if (counter[1:0] == 0 && counter != 0) begin
			//shift the raw data according to their weight,  14+4bit fixpoint
			conv_partial_sum[0] <= 	conv_partial_sum[0] 
									+ ((conv_raw_data[1] + conv_raw_data[4] + conv_raw_data[6] + conv_raw_data[9]) << 1) // * 2
									+ (conv_raw_data[0] + conv_raw_data[2] + conv_raw_data[8] + conv_raw_data[10]) // * 1
									+ (conv_raw_data[5] << 2); // * 4
			conv_partial_sum[1] <= 	conv_partial_sum[1] 
									+ ((conv_raw_data[2] + conv_raw_data[5] + conv_raw_data[7] + conv_raw_data[10]) << 1) // * 2
									+ (conv_raw_data[1] + conv_raw_data[3] + conv_raw_data[9] + conv_raw_data[11]) // * 1
									+ (conv_raw_data[6] << 2); // * 4
			end else if (counter[1:0] == 1 && counter != 1) begin
			conv_partial_sum[2] <= 	conv_partial_sum[2] 
									+ ((conv_raw_data[5] + conv_raw_data[8] + conv_raw_data[10] + conv_raw_data[13]) << 1) // * 2
									+ (conv_raw_data[4] + conv_raw_data[6] + conv_raw_data[12] + conv_raw_data[14]) // * 1
									+ (conv_raw_data[9] << 2); // * 4
			conv_partial_sum[3] <= 	conv_partial_sum[3] 
									+ ((conv_raw_data[6] + conv_raw_data[9] + conv_raw_data[11] + conv_raw_data[14]) << 1) // * 2
									+ (conv_raw_data[5] + conv_raw_data[7] + conv_raw_data[13] + conv_raw_data[15]) // * 1
									+ (conv_raw_data[10] << 2); // * 4
			end
		end
	end
end

	// round 
always @ (posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n ) begin
		for (j=0; j<4; j=j+1) begin
			conv_round[j] <= 0;
		end
	end else if (state_r == S_FETCHING) begin
		for (j=0; j<4; j=j+1) begin
			conv_round[j] <= 0;
		end
	end else begin
		if (state_r == S_CONV) begin
			if (counter == 4*channel_depth+1) begin
			//shift the raw data according to their weight,  14+4bit fixpoint
				conv_round[0] <= conv_partial_sum[0][17:4] + conv_partial_sum[0][3];
				conv_round[1] <= conv_partial_sum[1][17:4] + conv_partial_sum[1][3]; 
			end else if (counter == 4*channel_depth+2) begin
				conv_round[2] <= conv_partial_sum[2][17:4] + conv_partial_sum[2][3]; 
				conv_round[3] <= conv_partial_sum[3][17:4] + conv_partial_sum[3][3];
			end
		end
	end
end

//HARR//
	//read raw data for 1 channel
always @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n ) begin
		for (j=0; j<4; j=j+1) begin
			harr_raw_data[j] <= 0;
		end
	end else if ( state_r == S_FETCHING) begin
		for (j=0; j<4; j=j+1) begin
			harr_raw_data[j] <= 0;
		end
	end else begin
		if (state_r == S_HARR) begin
			case(counter[0]) // harr_raw_data is 1 cycle behind sram_address 
				1: begin
					harr_raw_data[0] <= sram_q[conv_sel[1]];
					harr_raw_data[1] <= sram_q[conv_sel[2]];
				end
				0: begin
					harr_raw_data[2] <= sram_q[conv_sel[1]];
					harr_raw_data[3] <= sram_q[conv_sel[2]];
				end
			endcase
		end
	end
end
	//partial sum accumulation

always @ (posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n ) begin
		for (j=0; j<4; j=j+1) 
			for (i=0; i<4; i=i+1) 
			harr_partial_sum[i][j] <= 0;
	end else if (state_r == S_FETCHING) begin
		for (j=0; j<4; j=j+1) 
			for (i=0; i<4; i=i+1) 
			harr_partial_sum[i][j] <= 0;
	end else begin
		if (state_r == S_HARR) begin
			if (counter[0] == 1 && counter != 1) begin
			//,  14bit fixpoint
			harr_partial_sum[0][counter[2:1]-1] <= 	harr_raw_data[0] + harr_raw_data[1] + harr_raw_data[2] + harr_raw_data[3];
			harr_partial_sum[1][counter[2:1]-1] <= 	harr_raw_data[0] - harr_raw_data[1] + harr_raw_data[2] - harr_raw_data[3];
			harr_partial_sum[2][counter[2:1]-1] <= 	harr_raw_data[0] + harr_raw_data[1] - harr_raw_data[2] - harr_raw_data[3];
			harr_partial_sum[3][counter[2:1]-1] <= 	$signed({6'd0, harr_raw_data[0]}) - $signed({6'd0, harr_raw_data[1]}) - $signed({6'd0, harr_raw_data[2]}) + $signed({6'd0, harr_raw_data[3]});
			end
			if (counter == 9) begin
			harr_partial_sum[0][3] <= 	harr_raw_data[0] + harr_raw_data[1] + harr_raw_data[2] + harr_raw_data[3];
			harr_partial_sum[1][3] <= 	harr_raw_data[0] - harr_raw_data[1] + harr_raw_data[2] - harr_raw_data[3];
			harr_partial_sum[2][3] <= 	harr_raw_data[0] + harr_raw_data[1] - harr_raw_data[2] - harr_raw_data[3];
			harr_partial_sum[3][3] <= 	{6'd0, harr_raw_data[0]} - {6'd0, harr_raw_data[1]} - {6'd0, harr_raw_data[2]} + {6'd0, harr_raw_data[3]};
			end
		end
	end
end

//MEDIAN//
// use the conv_raw_data
always @ (posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n ) begin
		for (j=0; j<4; j=j+1) 
			for (i=0; i<4; i=i+1) 
			median_result[i][j] <= 0;
	end else if (state_r == S_FETCHING) begin
		for (j=0; j<4; j=j+1) 
			for (i=0; i<4; i=i+1) 
			median_result[i][j] <= 0;
	end else begin
		if (state_r == S_MEDIAN) begin
			if (counter[1:0] == 0 && counter != 1) begin
				median_result[0][counter[3:2]-1] <= median_2(conv_raw_data[0], conv_raw_data[1], conv_raw_data[2], conv_raw_data[4], conv_raw_data[5], conv_raw_data[6], conv_raw_data[8], conv_raw_data[9], conv_raw_data[10]);
				median_result[1][counter[3:2]-1] <= median_2(conv_raw_data[1], conv_raw_data[2], conv_raw_data[3], conv_raw_data[5], conv_raw_data[6], conv_raw_data[7], conv_raw_data[9], conv_raw_data[10], conv_raw_data[11]);
			end else if (counter[1:0] == 1 && counter != 2) begin
				median_result[2][counter[3:2]-1] <= median_2(conv_raw_data[12], conv_raw_data[13], conv_raw_data[14], conv_raw_data[4], conv_raw_data[5], conv_raw_data[6], conv_raw_data[8], conv_raw_data[9], conv_raw_data[10]);
				median_result[3][counter[3:2]-1] <= median_2(conv_raw_data[5], conv_raw_data[6], conv_raw_data[7], conv_raw_data[9], conv_raw_data[10], conv_raw_data[11], conv_raw_data[13], conv_raw_data[14], conv_raw_data[15]);
			end
			if (counter == 16) begin
				median_result[0][3] <= median_2(conv_raw_data[0], conv_raw_data[1], conv_raw_data[2], conv_raw_data[4], conv_raw_data[5], conv_raw_data[6], conv_raw_data[8], conv_raw_data[9], conv_raw_data[10]);
				median_result[1][3] <= median_2(conv_raw_data[3], conv_raw_data[1], conv_raw_data[2], conv_raw_data[7], conv_raw_data[5], conv_raw_data[6], conv_raw_data[11], conv_raw_data[9], conv_raw_data[10]);
			end 
			if (counter == 17) begin
				median_result[2][3] <= median_2(conv_raw_data[12], conv_raw_data[13], conv_raw_data[14], conv_raw_data[4], conv_raw_data[5], conv_raw_data[6], conv_raw_data[8], conv_raw_data[9], conv_raw_data[10]);
				median_result[3][3] <= median_2(conv_raw_data[5], conv_raw_data[6], conv_raw_data[7], conv_raw_data[9], conv_raw_data[10], conv_raw_data[11], conv_raw_data[13], conv_raw_data[14], conv_raw_data[15]);
			end
		end
	end
end


always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		conv_out_valid_3	<= 0;
		conv_out_valid_2	<= 0;
		conv_out_valid_1	<= 0;
		conv_out_valid_0	<= 0;		
	end
	else if((state_r == S_CONV) && (counter == 4*channel_depth+1)) begin
		conv_out_valid_3	<= 1;
		conv_out_valid_2	<= 1;
		conv_out_valid_1	<= 1;
		conv_out_valid_0	<= 1;
	end
	else begin
		conv_out_valid_3	<= 0;
		conv_out_valid_2	<= conv_out_valid_3;	
		conv_out_valid_1	<= conv_out_valid_2;
		conv_out_valid_0	<= conv_out_valid_1;
	end
end	
always @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		conv_counter <= 0;
	end else if ((state_r == S_CONV) && (counter == 4*channel_depth+2)) begin
		conv_counter <= 0;
	end else begin
		conv_counter <= conv_counter + 1;
	end
end

always @ (posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_IDLE;
		op_mode_r <= 0;
		counter <= 0;
		origin_row <= 0;
		origin_col <= 0;
		channel_depth <= DEPTH_32;
		display_sel <= 0;
		o_out_valid_reg <= 0;
		o_in_ready_reg <= 0;
	end else begin
		state_r <= state_w;
		op_mode_r <= op_mode_w;
		counter <= counter_nxt;
		origin_row <= origin_row_nxt;
		origin_col <= origin_col_nxt;
		channel_depth <= channel_depth_nxt;
		display_sel <= sram_sel; // for display
		o_out_valid_reg <= (state_r == S_DISPLAY) || (conv_out_valid_0) || (state_r == S_HARR_BUF) ||(state_r == S_HARR_OP) || (state_r == S_MEDIAN_BUF) || (state_r == S_MEDIAN_OP);
		o_in_ready_reg <= 1;
	end
end


endmodule
