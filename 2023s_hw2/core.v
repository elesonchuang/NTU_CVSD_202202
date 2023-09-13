module core #(                             //Don't modify interface
	parameter ADDR_W = 32,
	parameter INST_W = 32,
	parameter DATA_W = 32
)(
	input                   i_clk,
	input                   i_rst_n,
	output [ ADDR_W-1 : 0 ] o_i_addr,
	input  [ INST_W-1 : 0 ] i_i_inst,
	output                  o_d_we,
	output [ ADDR_W-1 : 0 ] o_d_addr,
	output [ DATA_W-1 : 0 ] o_d_wdata,
	input  [ DATA_W-1 : 0 ] i_d_rdata,
	output [        1 : 0 ] o_status,
	output                  o_status_valid
);

//params for FSM//
localparam  IDLE = 3'b000,		// Reset 
			FETCHING = 3'b001, 	// after generating PC, in this state, the new o_i_addr will be outputted, and the new inst can be read in next cycle
			DECODING = 3'b010, 	// decode the inst, check eof, update some control signal
			COMPUTING = 3'b011, // do ALU computing 
			WRITE_BACK = 3'b100,// handle the write back of register file and memory.
			NXT_PC_GEN = 3'b101,// generating next PC, pc_w should only be changed in this state.
			PC_END = 3'b110; 	// eof

//params for inst_type//
localparam  Rtype = 2'd0,
			Itype = 2'd1,
			EOFtype = 2'd2;


// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //
reg  [ DATA_W-1 : 0 ] register [ 0 : ADDR_W-1 ];  // bit num , num , register[1][2] => the 2nd bit of 1st register
reg  [ 		  2 : 0 ] state_r, state_w;
reg  [ ADDR_W-1 : 0 ] pc_r, pc_w;
reg  [		  1 : 0 ] inst_type;
reg ALU_overflow, ALU_branch;
reg rf_write_en;
reg  [ DATA_W-1 : 0 ] ALU_output;



wire [		  5 : 0 ] opcode;
wire [		  4 : 0 ] s2, s3, s1;
wire [		 15 : 0 ] im;
wire eof, overflow;
wire [		  4 : 0 ] rf_write_addr;
wire [ DATA_W-1 : 0 ] rf_write_data;

wire alu_in2_im;
wire [ DATA_W-1 : 0 ] alu_in_1;
wire [ DATA_W-1 : 0 ] alu_in_2; // handle whether immediate or data in register should be process
wire [   DATA_W : 0 ] sum, sub;// for overflow check

wire inst_overflow, data_overflow;

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
assign o_i_addr = pc_r;



// handle all overflow condictions
assign inst_overflow = |pc_w[ADDR_W-1:12];
assign data_overflow = ((opcode == `OP_LW) | (opcode == `OP_SW)) && (|o_d_addr[ADDR_W-1:8]);
assign overflow		 = inst_overflow | data_overflow | ALU_overflow;

// decoding
assign opcode = i_i_inst[31:26];
assign s2	  = i_i_inst[25:21];
assign s3 	  = i_i_inst[20:16]; // note that this is s1 for i type inst
assign s1 	  =	i_i_inst[15:11];
assign im 	  = i_i_inst[15:0]; 
assign eof	  = (inst_type == EOFtype);

// alu
assign alu_in_1 = register[s2];
assign alu_in2_im = ( (opcode == `OP_ADDI) | (opcode == `OP_LW) | (opcode == `OP_SW) );
assign alu_in_2 = (alu_in2_im) ? { { DATA_W-16{im[15]} } , im} : register[s3];
assign sum = {alu_in_1[DATA_W-1], alu_in_1} + {alu_in_2[DATA_W-1], alu_in_2}; // sign extend by 1 bit 
assign sub = {alu_in_1[DATA_W-1], alu_in_1} - {alu_in_2[DATA_W-1], alu_in_2}; // sign extend by 1 bit 


// write back
assign rf_write_addr = (inst_type == Itype) ? s3 : s1; //note that s3 is s1 for i type inst
assign rf_write_data = (state_r == WRITE_BACK) ? (
						(rf_write_en) ? ((opcode == `OP_LW) ? (i_d_rdata) : (ALU_output) ) : (register[rf_write_addr])
												) : register[rf_write_addr];
assign o_d_we = (opcode == `OP_SW) & (state_r == WRITE_BACK);
assign o_d_addr = ALU_output;
assign o_d_wdata = register[s3]; // note that s3 is s1 for i type inst

// output state / valid
assign o_status_valid = (state_r == NXT_PC_GEN) | (state_r == PC_END);
assign o_status = (overflow) ? `MIPS_OVERFLOW : (
				  	(eof)	 ? `MIPS_END	  : (
					(inst_type == Rtype) ? (`R_TYPE_SUCCESS) : (`I_TYPE_SUCCESS) 
					)
				  );
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //

//FSM//
always @(*) begin
	case (state_r) //synopsys full_case
		IDLE:		state_w = FETCHING;
		FETCHING:	state_w = DECODING;
		DECODING:	state_w = (eof) 	 ? 	 PC_END : COMPUTING;
		COMPUTING:	state_w = (overflow) ?	 PC_END : WRITE_BACK;
		WRITE_BACK: state_w = NXT_PC_GEN;
		NXT_PC_GEN: state_w = (overflow) ?	 PC_END : FETCHING;
		PC_END:		state_w = PC_END;
	endcase
end


//decoding
always @(*) begin // check inst type 
	inst_type = Rtype;
	case (opcode)
		`OP_ADDI:inst_type = Itype;
		`OP_LW:inst_type = Itype;
		`OP_SW:inst_type = Itype;
		`OP_BEQ:inst_type = Itype;
		`OP_BNE:inst_type = Itype;
		`OP_BLT:inst_type = Itype;
		`OP_BGE:inst_type = Itype;
		`OP_BLTU:inst_type = Itype;
		`OP_BGEU:inst_type = Itype;
		`OP_EOF:inst_type = EOFtype;
	endcase
end
//rf enable
always @(*) begin
	rf_write_en = 0;
	case (opcode)
		`OP_ADD: rf_write_en = 1;
		`OP_SUB: rf_write_en = 1;
		`OP_ADDU: rf_write_en = 1;
		`OP_SUBU: rf_write_en = 1;
		`OP_ADDI: rf_write_en = 1;
		`OP_LW: rf_write_en = 1;
		`OP_AND: rf_write_en = 1;
		`OP_OR: rf_write_en = 1;
		`OP_XOR: rf_write_en = 1;
		`OP_SLL: rf_write_en = 1;
		`OP_SRL: rf_write_en = 1;
		`OP_SLT: rf_write_en = 1;
	endcase
end


//ALU
always @(*) begin
	ALU_output = 0;
	ALU_branch = 0;
	ALU_overflow = 0;
	case (opcode)
		`OP_ADD:begin
			ALU_output 		= sum[DATA_W-1:0];
			ALU_overflow  	= (sum[DATA_W] ^ sum[DATA_W-1]);
		end
		`OP_SUB:begin
			ALU_output 		= sub[DATA_W-1:0];
			ALU_overflow	= (sub[DATA_W] ^ sub[DATA_W-1]);
		end
		`OP_ADDU:begin
			{ALU_overflow, ALU_output} = alu_in_1 + alu_in_2;
		end
		`OP_SUBU:begin
			{ALU_overflow, ALU_output} = alu_in_1 - alu_in_2;
		end
		`OP_ADDI:begin
			ALU_output 		= sum[DATA_W-1:0];
			ALU_overflow  	= (sum[DATA_W] ^ sum[DATA_W-1]);
		end
		`OP_LW:begin // same as addi
			ALU_output 		= sum[DATA_W-1:0];
			ALU_overflow  	= (sum[DATA_W] ^ sum[DATA_W-1]);
		end
		`OP_SW:begin // same as addi
			ALU_output 		= sum[DATA_W-1:0];
			ALU_overflow  	= (sum[DATA_W] ^ sum[DATA_W-1]);
		end
		`OP_AND: ALU_output = alu_in_1 &  alu_in_2;
		`OP_OR:	 ALU_output = alu_in_1 |  alu_in_2;
		`OP_XOR: ALU_output = alu_in_1 ^  alu_in_2;
		`OP_BEQ: ALU_branch = alu_in_1 == alu_in_2;
		`OP_BNE: ALU_branch = alu_in_1 != alu_in_2;
		`OP_SLT: ALU_output = $signed(alu_in_1) < $signed(alu_in_2);
		`OP_SLL: ALU_output = alu_in_1 << alu_in_2;
		`OP_SRL: ALU_output = alu_in_1 >> alu_in_2;
		`OP_BLT: ALU_branch = $signed(alu_in_2) <  $signed(alu_in_1); //if($s1<$s2), note that for i type, alu_in_2 is s1.
		`OP_BGE: ALU_branch = $signed(alu_in_2) >= $signed(alu_in_1); //if($s1>=$s2), note that for i type, alu_in_2 is s1.
		`OP_BLTU:ALU_branch = alu_in_2 <  alu_in_1;
		`OP_BGEU:ALU_branch = alu_in_2 >= alu_in_1;
	endcase
end


// NXT_PC_GEN
always @(*) begin
	if (state_r == NXT_PC_GEN) begin
		pc_w = (ALU_branch) ? (pc_r + { { DATA_W-16{im[15]} } , im}) : (pc_r + 4);
	end else begin
		pc_w = pc_r;
	end
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //


integer i;
always@(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
		state_r <= IDLE; // FSM
		pc_r <= 0; // PC
		for (i = 0; i < ADDR_W; i = i + 1) // RF
			register[i] <= 0;
    end else begin
		state_r <= state_w; // FSM
		pc_r <= pc_w;
		register[rf_write_addr] <= rf_write_data; 
    end
end


endmodule