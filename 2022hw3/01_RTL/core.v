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
	output [12:0] o_out_data
);

parameter OP_LOAD    = 4'b0000;
parameter OP_RIGHT   = 4'b0001;
parameter OP_LEFT    = 4'b0010;
parameter OP_UP      = 4'b0011;
parameter OP_DOWN    = 4'b0100;
parameter OP_CN_DOWN = 4'b0101;
parameter OP_CN_UP   = 4'b0110;
parameter OP_CONV    = 4'b0111;
parameter OP_DIS     = 4'b1000; 


// ====================== wire/reg ========================= //
reg [10:0] counter_2047;
reg  [7:0] counter_256;
reg  [5:0] dis_size, dis_size_nxt;

reg  [7:0] in_data;
reg  [3:0] op, op_mode;
reg  [2:0] origin_row, origin_col;
reg        in_ready, op_ready, op_ready_nxt, op_valid;

// ====================== read-in ========================= //
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		in_data	<= 0;
		op_valid	<= 0;
		op_mode	<= 0;
		op	<= 0;	
	end 
	else begin
		in_data  <= i_in_data;
		op_valid <= i_op_valid;
		op_mode  <= i_op_mode;
		if(op_valid) op <= op_mode;
		
	end
end

// ========================= FSM =========================== //
parameter S_IDLE  = 4'd0;
parameter S_READY = 4'd1;
parameter S_BUF1  = 4'd2;
parameter S_BUF2  = 4'd3;
parameter S_LOAD  = 4'd4;
parameter S_FIRE  = 4'd5;
parameter S_BUF3  = 4'd6;
parameter S_GOP   = 4'd7;
parameter S_BUF4  = 4'd8;
parameter S_DIS4  = 4'd9;
parameter S_DIS2  = 4'd10;
parameter S_DIS1  = 4'd11;
parameter S_BUF6  = 4'd12;
parameter S_BUF7  = 4'd13;
parameter S_BUF8  = 4'd14;
parameter S_BUF5  = 4'd15;


parameter DIS_8x4 = 6'd32;
parameter DIS_8x2 = 6'd16;
parameter DIS_8x1 = 6'd8;

reg [3:0] state, state_nxt;

always@(*) begin
	state_nxt = state;
	case(state)
		S_IDLE : state_nxt = S_READY;
		S_READY: state_nxt = S_BUF1;
		S_BUF1 : state_nxt = S_BUF2;
		S_BUF2 : state_nxt = S_LOAD;
		S_LOAD : if(counter_2047 == 2047) state_nxt = S_BUF5;
		S_FIRE : state_nxt = S_BUF3;
		S_BUF3 : state_nxt = S_GOP;
		S_GOP  : state_nxt = S_BUF4;
		S_BUF4 : begin
			if(op != OP_DIS && op != OP_CONV)	state_nxt = S_BUF5;
			else if(dis_size == DIS_8x4)	state_nxt = S_DIS4;
			else if(dis_size == DIS_8x2)	state_nxt = S_DIS2;
			else if(dis_size == DIS_8x1)	state_nxt = S_DIS1;
			end
		S_DIS4 : begin
			if	(op == OP_DIS  && counter_256 == (4*dis_size-1)) state_nxt = S_BUF6;
			else if	(op == OP_CONV && counter_256 == (4*dis_size+2)) state_nxt = S_BUF6;
		end
		S_DIS2 : begin
			if	(op == OP_DIS  && counter_256 == (4*dis_size-1)) state_nxt = S_BUF6;
			else if	(op == OP_CONV && counter_256 == (4*dis_size+2)) state_nxt = S_BUF6;
		end
		S_DIS1 : begin
			if	(op == OP_DIS  && counter_256 == (4*dis_size-1)) state_nxt = S_BUF6;
			else if	(op == OP_CONV && counter_256 == (4*dis_size+2)) state_nxt = S_BUF6;
		end
		S_BUF6 : state_nxt = S_BUF7;
		S_BUF7 : state_nxt = S_BUF8;
		S_BUF8 : state_nxt = S_BUF5;
		S_BUF5 : state_nxt = S_FIRE;
	endcase
end

always@(*) begin
	op_ready_nxt = 0;
	case(state)
		S_IDLE : op_ready_nxt = 1;
		S_READY: op_ready_nxt = 0;
		S_FIRE : op_ready_nxt = 0;
		S_BUF5 : op_ready_nxt = 1;
	endcase
end

always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		state	<= S_IDLE;
		op_ready	<= 0;
	end 
	else begin
		state	<= state_nxt;
		op_ready	<= op_ready_nxt;
	end
end

// ============= counter 2047 (for S_LOAD) ================= //
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n)		counter_2047 <= 0;	
	else if(state == S_BUF2)	counter_2047 <= 0;
	else if(state == S_LOAD)	counter_2047 <= counter_2047+1;
end

//integer j = 0;
// ============= counter 256 (for S_DIS?) ================== //
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n)		counter_256	<= 0;
	else if(state == S_BUF4)	counter_256	<= 0;
	else if(state == S_DIS4 || state == S_DIS2 || state == S_DIS1)
				counter_256	<= counter_256+1;
end

// =============== display size ================== //
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		dis_size		<= DIS_8x4;
		dis_size_nxt	<= DIS_8x4;
	end
	else if(state == S_BUF4 && op == OP_CN_DOWN && dis_size == DIS_8x4) 
		dis_size_nxt	<= DIS_8x2;
	else if(state == S_BUF4 && op == OP_CN_DOWN && dis_size == DIS_8x2) 
		dis_size_nxt	<= DIS_8x1;
	else if(state == S_BUF4 && op == OP_CN_UP && dis_size == DIS_8x2) 
		dis_size_nxt	<= DIS_8x4;
	else if(state == S_BUF4 && op == OP_CN_UP && dis_size == DIS_8x1) 
		dis_size_nxt	<= DIS_8x2;
	else if(state == S_BUF5) 
		dis_size 	<= dis_size_nxt;
end


// ============= origin_coordinate =================== //
wire [4:0] ori_R, ori_L, ori_D, ori_U;
wire       R_vio, L_vio, D_vio, U_vio;

assign ori_R = origin_col+1;
assign ori_L = origin_col-1;
assign ori_D = origin_row+1;
assign ori_U = origin_row-1;

assign R_vio = (origin_col==6);
assign L_vio = (origin_col==0);
assign D_vio = (origin_row==6);
assign U_vio = (origin_row==0);

always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		origin_col <= 0;
		origin_row <= 0;
	end 
	else if(state == S_BUF4) begin
		if(op == OP_RIGHT && !R_vio)     origin_col <= ori_R;
		else if(op == OP_LEFT && !L_vio) origin_col <= ori_L;
		else if(op == OP_DOWN && !D_vio) origin_row <= ori_D;
		else if(op == OP_UP && !U_vio)   origin_row <= ori_U;
	end
end

// ============= conv_coordinate =================== //
wire [2:0] conv_row [3:0];
wire [2:0] conv_col [3:0];
wire [1:0] order	   [3:0];

assign conv_row[0] = origin_row-1;
assign conv_row[1] = origin_row;
assign conv_row[2] = origin_row+1;
assign conv_row[3] = origin_row+2;

assign conv_col[0] = origin_col-1;
assign conv_col[1] = origin_col;
assign conv_col[2] = origin_col+1;
assign conv_col[3] = origin_col+2;

assign order[0] = conv_col[0][1:0];
assign order[1] = conv_col[1][1:0];
assign order[2] = conv_col[2][1:0];
assign order[3] = conv_col[3][1:0]; 

// ================= sram ====================== //
reg [10:0] sram_addr	[3:0]; 
wire [7:0] q		[3:0];
wire sram_wen_0 = (state == S_LOAD)? (sram_addr[0][1:0]!=0) : 1;
wire sram_wen_1 = (state == S_LOAD)? (sram_addr[1][1:0]!=1) : 1;
wire sram_wen_2 = (state == S_LOAD)? (sram_addr[2][1:0]!=2) : 1;
wire sram_wen_3 = (state == S_LOAD)? (sram_addr[3][1:0]!=3) : 1;

always@(*) begin
	sram_addr[0] = counter_2047; // load images
	sram_addr[1] = counter_2047; // load images
	sram_addr[2] = counter_2047; // load images
	sram_addr[3] = counter_2047; // load images
         if((op == OP_DIS) && (state==S_DIS4||state==S_DIS2||state==S_DIS1)) begin
		case(counter_256[1:0])
			2'b00: begin
				sram_addr[0] = {counter_256[6:2], origin_row, origin_col};
				sram_addr[1] = {counter_256[6:2], origin_row, origin_col};
				sram_addr[2] = {counter_256[6:2], origin_row, origin_col};
				sram_addr[3] = {counter_256[6:2], origin_row, origin_col};
			end
			2'b01: begin
				sram_addr[0] = {counter_256[6:2], origin_row, origin_col}+1;
				sram_addr[1] = {counter_256[6:2], origin_row, origin_col}+1;
				sram_addr[2] = {counter_256[6:2], origin_row, origin_col}+1;
				sram_addr[3] = {counter_256[6:2], origin_row, origin_col}+1;
			end
			2'b10: begin
				sram_addr[0] = {counter_256[6:2], origin_row, origin_col}+8;
				sram_addr[1] = {counter_256[6:2], origin_row, origin_col}+8;
				sram_addr[2] = {counter_256[6:2], origin_row, origin_col}+8;
				sram_addr[3] = {counter_256[6:2], origin_row, origin_col}+8;
			end
			2'b11: begin
				sram_addr[0] = {counter_256[6:2], origin_row, origin_col}+9;
				sram_addr[1] = {counter_256[6:2], origin_row, origin_col}+9;
				sram_addr[2] = {counter_256[6:2], origin_row, origin_col}+9;
				sram_addr[3] = {counter_256[6:2], origin_row, origin_col}+9;
			end
		endcase 
	end
         else if((op == OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1)) begin
		case(counter_256[1:0])
			2'b00: begin
				sram_addr[conv_col[0][1:0]] = {counter_256[6:2], conv_row[0], conv_col[0]};
				sram_addr[conv_col[1][1:0]] = {counter_256[6:2], conv_row[0], conv_col[1]};
				sram_addr[conv_col[2][1:0]] = {counter_256[6:2], conv_row[0], conv_col[2]};
				sram_addr[conv_col[3][1:0]] = {counter_256[6:2], conv_row[0], conv_col[3]};
			end
			2'b01: begin
				sram_addr[conv_col[0][1:0]] = {counter_256[6:2], conv_row[1], conv_col[0]};
				sram_addr[conv_col[1][1:0]] = {counter_256[6:2], conv_row[1], conv_col[1]};
				sram_addr[conv_col[2][1:0]] = {counter_256[6:2], conv_row[1], conv_col[2]};
				sram_addr[conv_col[3][1:0]] = {counter_256[6:2], conv_row[1], conv_col[3]};
			end
			2'b10: begin
				sram_addr[conv_col[0][1:0]] = {counter_256[6:2], conv_row[2], conv_col[0]};
				sram_addr[conv_col[1][1:0]] = {counter_256[6:2], conv_row[2], conv_col[1]};
				sram_addr[conv_col[2][1:0]] = {counter_256[6:2], conv_row[2], conv_col[2]};
				sram_addr[conv_col[3][1:0]] = {counter_256[6:2], conv_row[2], conv_col[3]};
			end
			2'b11: begin
				sram_addr[conv_col[0][1:0]] = {counter_256[6:2], conv_row[3], conv_col[0]};
				sram_addr[conv_col[1][1:0]] = {counter_256[6:2], conv_row[3], conv_col[1]};
				sram_addr[conv_col[2][1:0]] = {counter_256[6:2], conv_row[3], conv_col[2]};
				sram_addr[conv_col[3][1:0]] = {counter_256[6:2], conv_row[3], conv_col[3]};
			end
		endcase
	end
end

sram_512x8 number_0 (.Q(q[0]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen_0), .A(sram_addr[0][10:2]), .D(in_data));
sram_512x8 number_1 (.Q(q[1]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen_1), .A(sram_addr[1][10:2]), .D(in_data));
sram_512x8 number_2 (.Q(q[2]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen_2), .A(sram_addr[2][10:2]), .D(in_data));
sram_512x8 number_3 (.Q(q[3]), .CLK(i_clk), .CEN(1'b0), .WEN(sram_wen_3), .A(sram_addr[3][10:2]), .D(in_data));

// ================= CONV Compute ====================== //
reg [7:0]  x [15:0];
reg [16:0] y [3:0];
reg [12:0] z [3:0]; 
wire       conv_row_ok [3:0]; 
wire       conv_col_ok [3:0];

assign conv_row_ok[0] = (origin_row!=0);
assign conv_row_ok[1] = 1;
assign conv_row_ok[2] = 1;
assign conv_row_ok[3] = (origin_row!=6);

assign conv_col_ok[0] = (origin_col!=0);
assign conv_col_ok[1] = 1;
assign conv_col_ok[2] = 1;
assign conv_col_ok[3] = (origin_col!=6);

integer i;
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		for(i=0 ; i<16 ; i=i+1)
			x[i] <= 0;
	end
	else if(state==S_BUF4) begin
		for(i=0 ; i<16 ; i=i+1)
			x[i] <= 0;
	end
	else if((op == OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1) && (counter_256>0)) begin	
		case(counter_256[1:0])
			2'b01: begin
				x[0] <= (conv_row_ok[0] && conv_col_ok[0])? q[order[0]]:0;
				x[1] <= (conv_row_ok[0] && conv_col_ok[1])? q[order[1]]:0;
				x[2] <= (conv_row_ok[0] && conv_col_ok[2])? q[order[2]]:0;
				x[3] <= (conv_row_ok[0] && conv_col_ok[3])? q[order[3]]:0;
			end
			2'b10: begin
				x[4] <= (conv_row_ok[1] && conv_col_ok[0])? q[order[0]]:0;
				x[5] <= (conv_row_ok[1] && conv_col_ok[1])? q[order[1]]:0;
				x[6] <= (conv_row_ok[1] && conv_col_ok[2])? q[order[2]]:0;
				x[7] <= (conv_row_ok[1] && conv_col_ok[3])? q[order[3]]:0;
			end
			2'b11: begin
				x[8]  <= (conv_row_ok[2] && conv_col_ok[0])? q[order[0]]:0;
				x[9]  <= (conv_row_ok[2] && conv_col_ok[1])? q[order[1]]:0;
				x[10] <= (conv_row_ok[2] && conv_col_ok[2])? q[order[2]]:0;
				x[11] <= (conv_row_ok[2] && conv_col_ok[3])? q[order[3]]:0;
			end
			2'b00: begin
				x[12] <= (conv_row_ok[3] && conv_col_ok[0])? q[order[0]]:0;
				x[13] <= (conv_row_ok[3] && conv_col_ok[1])? q[order[1]]:0;
				x[14] <= (conv_row_ok[3] && conv_col_ok[2])? q[order[2]]:0;
				x[15] <= (conv_row_ok[3] && conv_col_ok[3])? q[order[3]]:0;
			end
		endcase
	end	
end

always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		y[0] <= 0;
		y[1] <= 0;
		y[2] <= 0;
		y[3] <= 0;
	end	
	else if(state==S_BUF4) begin
		y[0] <= 0;
		y[1] <= 0;
		y[2] <= 0;
		y[3] <= 0;
	end	
	else if((op == OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1) 
		&& (counter_256[1:0]==0) && (counter_256>0) ) begin
		y[0] <= y[0]+(x[5]<<2)+((x[1]+x[4]+x[6]+x[9])<<1)+(x[0]+x[2]+x[8]+x[10]);
		y[1] <= y[1]+(x[6]<<2)+((x[2]+x[5]+x[7]+x[10])<<1)+(x[1]+x[3]+x[9]+x[11]);	
	end
	else if((op == OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1) 
		&& (counter_256[1:0]==1) && (counter_256>1) ) begin
		y[2] <= y[2]+(x[9]<<2)+((x[5]+x[8]+x[10]+x[13])<<1)+(x[4]+x[6]+x[12]+x[14]);
		y[3] <= y[3]+(x[10]<<2)+((x[6]+x[9]+x[11]+x[14])<<1)+(x[5]+x[7]+x[13]+x[15]);
	end
end	

always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		z[0] <= 0;
		z[1] <= 0;
		z[2] <= 0;
		z[3] <= 0;
	end	
	else if(state==S_BUF4) begin
		z[0] <= 0;
		z[1] <= 0;
		z[2] <= 0;
		z[3] <= 0;
	end	
	else if((op == OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1) 
		&& (counter_256 == (4*dis_size+1)) ) begin
			z[0] <= y[0][16:4]+y[0][3];
			z[1] <= y[1][16:4]+y[1][3];
	end
	else if((op == OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1) 
		&& (counter_256 == (4*dis_size+2)) ) begin
			z[2] <= y[2][16:4]+y[2][3];
			z[3] <= y[3][16:4]+y[3][3];
	end	
end	

// ============= out_valid / out_data =================== //
reg [10:0]	sram_addr_prev;
reg [1:0]	CONV_out_num;
reg	CONV_out_valid_3nxt, CONV_out_valid_2nxt, CONV_out_valid_nxt, CONV_out_valid;
reg	DIS_out_valid;
wire 	DIS_out_valid_nxt = ((op==OP_DIS) && (state==S_DIS4||state==S_DIS2||state==S_DIS1));

wire [12:0] 	DIS_out_data	= {5'b0, q[sram_addr_prev[1:0]]}; 
wire [12:0]	CONV_out_data	= z[CONV_out_num];
	
always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		in_ready		<= 0;
		DIS_out_valid	<= 0;	
		CONV_out_num	<= 0;
		sram_addr_prev	<= 0;
	end		
	else begin
		in_ready		<= 1;
		DIS_out_valid	<= DIS_out_valid_nxt;	
		CONV_out_num	<= CONV_out_num + CONV_out_valid;
		sram_addr_prev	<= sram_addr[0];
	end
end	

always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		CONV_out_valid_3nxt	<= 0;
		CONV_out_valid_2nxt	<= 0;
		CONV_out_valid_nxt	<= 0;
		CONV_out_valid		<= 0;		
	end
	else if((op==OP_CONV) && (state==S_DIS4||state==S_DIS2||state==S_DIS1) && (counter_256==4*dis_size+2)) begin
		CONV_out_valid_3nxt	<= 1;
		CONV_out_valid_2nxt	<= 1;
		CONV_out_valid_nxt	<= 1;
		CONV_out_valid		<= 1;
	end
	else begin
		CONV_out_valid_3nxt	<= 0;
		CONV_out_valid_2nxt	<= CONV_out_valid_3nxt;	
		CONV_out_valid_nxt	<= CONV_out_valid_2nxt;
		CONV_out_valid		<= CONV_out_valid_nxt;
	end
end	

// ============= output assignment =================== //
assign o_in_ready  = in_ready;
assign o_op_ready  = op_ready;
assign o_out_valid = (op == OP_DIS)? DIS_out_valid : CONV_out_valid;
assign o_out_data  = (op == OP_DIS)? DIS_out_data : CONV_out_data;

endmodule