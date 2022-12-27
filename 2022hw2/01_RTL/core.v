module core #(                             //Don't modify interface
	parameter ADDR_W = 32,
	parameter INST_W = 32,
	parameter DATA_W = 32
)(
	input                   i_clk,
	input                   i_rst_n,
	output [ ADDR_W-1 : 0 ] o_i_addr,
	input  [ INST_W-1 : 0 ] i_i_inst,
	output                  o_d_wen,
	output [ ADDR_W-1 : 0 ] o_d_addr,
	output [ DATA_W-1 : 0 ] o_d_wdata,
	input  [ DATA_W-1 : 0 ] i_d_rdata,
	output [        1 : 0 ] o_status,
	output                  o_status_valid
);

//------------------------------------------------------//
// MyStep1: state machine(Idle, Calculate, Update, End) //
//------------------------------------------------------//
parameter Idle      = 2'd0;
parameter Calculate = 2'd1;
parameter Update    = 2'd2;
parameter End       = 2'd3;

wire isOverflow, isEOF;
reg [1:0] state_now, state_next;

always@(*) begin
    case(state_now)
        Idle:       state_next = Calculate;
        Calculate:  state_next = (isOverflow|isEOF)?End:Update;
        Update:     state_next = Calculate;
        End:        state_next = End;  
    endcase
end

always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) state_now <= Idle;
    else         state_now <= state_next;
end


//-----------------------------------------------------//
// MyStep2: State Machine - Idle & To maintain address //
//-----------------------------------------------------//
reg  [ADDR_W-1:0] Idle_addr_r;
wire [ADDR_W-1:0] Idle_addr_w;

always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) 
        Idle_addr_r <= 0;
    else if(state_now==Calculate) 
        Idle_addr_r <= Idle_addr_w;
end 

assign o_i_addr = Idle_addr_r;


//-------------------------------------------------------------//
// MyStep3: State Machine - Calculate & To preprocess+Category //
//-------------------------------------------------------------//
reg  [3:0] aluop;
wire readMemory, writeMemory, writeRegister;
wire hasBranch, alu_hasBranch;
wire inst_isOverflow, data_isOverflow, alu_isOverflow;

wire [5:0] opcode;
wire [4:0] addr_part1, addr_part2, addr_s1;
wire       isI_TYPE;
wire [1:0] status;
reg  [1:0] Update_status_r;
wire [1:0] Update_status_w;
reg        Update_status_valid_r;
wire       Update_status_valid_w;


assign Idle_addr_w = Idle_addr_r+4+((hasBranch&alu_hasBranch)?i_i_inst[15:0]:0);

assign opcode      = i_i_inst[31:26];
assign addr_part1  = i_i_inst[25:21];
assign addr_part2  = i_i_inst[20:16];
assign addr_s1     = (status==`R_TYPE_SUCCESS)?i_i_inst[15:11]:addr_part2;

assign isI_TYPE = (opcode==`OP_ADDI)|(opcode==`OP_LW)|(opcode==`OP_SW)|(opcode==`OP_BEQ)|(opcode==`OP_BNE);
assign status   = (opcode==`OP_EOF)? `MIPS_END : ((isI_TYPE)?`I_TYPE_SUCCESS:`R_TYPE_SUCCESS);
assign Update_status_w       = (isOverflow&&(!isEOF))?`MIPS_OVERFLOW:status;
assign Update_status_valid_w = (state_now==Update)|(state_now==End);
 
assign readMemory   = (opcode==`OP_LW);
assign writeMemory  = (opcode==`OP_SW);
assign writeRegister = (status==`R_TYPE_SUCCESS)|(opcode==`OP_ADDI)|(opcode==`OP_LW);
assign hasBranch   = (opcode==`OP_BEQ)|(opcode==`OP_BNE);
assign isEOF        = (opcode==`OP_EOF); 

assign inst_isOverflow = (Idle_addr_r[31:12]>0);
assign data_isOverflow = (readMemory|writeMemory)&&(o_d_addr[31:8]>0);
assign isOverflow = inst_isOverflow || data_isOverflow || alu_isOverflow;
 
always@(*) begin
    case(opcode)
        `OP_ADD:  aluop = `ALU_ADD;
        `OP_SUB:  aluop = `ALU_SUB;
        `OP_ADDU: aluop = `ALU_ADDU;
        `OP_SUBU: aluop = `ALU_SUBU;
        `OP_ADDI: aluop = `ALU_ADD;
        `OP_LW:   aluop = `ALU_ADD;
        `OP_SW:   aluop = `ALU_ADD;
        `OP_AND:  aluop = `ALU_AND;
        `OP_OR:   aluop = `ALU_OR;
        `OP_NOR:  aluop = `ALU_NOR;
        `OP_BEQ:  aluop = `ALU_BEQ;
        `OP_BNE:  aluop = `ALU_BNE;
        `OP_SLT:  aluop = `ALU_SLT;
        default:  aluop = 0;
    endcase
end


//--------------------------------------------------------------------//
// MyStep4: State Machine - Update & Take data from register/Memory   //
//--------------------------------------------------------------------//
wire[DATA_W-1:0] data_2_ForALU;
wire[DATA_W-1:0] alu_out, data_1_FromReg, data_2_FromReg, data_s1_ToWrite;

assign data_2_ForALU = ((opcode==`OP_ADDI)|(opcode==`OP_LW)|(opcode==`OP_SW))? 
                    {{16{i_i_inst[15]}},i_i_inst[15:0]} : data_2_FromReg;
assign data_s1_ToWrite = readMemory?i_d_rdata:alu_out;

reg_file u_reg(
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_read_addr1(addr_part1),
    .i_read_addr2(addr_part2),
    .o_read_data1(data_1_FromReg),
    .o_read_data2(data_2_FromReg),
    .i_needWrite(writeRegister&(state_now==Update)),
    .i_write_addr(addr_s1),
    .i_write_data(data_s1_ToWrite)
);


alu u_alu(
    .i_aluop(aluop),
    .i_data1(data_1_FromReg),
    .i_data2(data_2_ForALU),
    .o_alu_isOverflow(alu_isOverflow),
    .o_alu_hasBranch(alu_hasBranch),
    .o_alu_out(alu_out)
);


always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        Update_status_r       <= 0;
        Update_status_valid_r <= 0;
    end
    else begin
        Update_status_r       <= Update_status_w;
        Update_status_valid_r <= Update_status_valid_w;
    end
end

assign o_d_wen   = writeMemory&(state_now==Update);
assign o_d_addr  = alu_out;
assign o_d_wdata = data_2_FromReg;
assign o_status       = Update_status_r;
assign o_status_valid = Update_status_valid_r;

endmodule
