module alu (
    input      [3:0]  i_aluop,
    input      [31:0] i_data1,
    input      [31:0] i_data2,
    output reg        o_alu_isOverflow,
    output reg        o_alu_hasBranch,
    output reg [31:0] o_alu_out
);
reg [31:0] temp;
reg [32:0] sum;

always@(*) begin
    o_alu_out        = 0;
    o_alu_isOverflow = 0;
    o_alu_hasBranch  = 0;
    temp = 0;
    sum  = 0;

    case(i_aluop)
        `ALU_ADD: begin
            temp = i_data1+i_data2;
            o_alu_out        = temp;
            o_alu_isOverflow = (i_data1[31]==i_data2[31])&&(i_data1[31]!=temp[31]);
        end 
        `ALU_SUB: begin
            temp = ~i_data2+1;
            temp = i_data1+temp;
            o_alu_out        = temp;
            o_alu_isOverflow = (i_data1[31]==i_data2[31])&&(i_data1[31]!=temp[31]);
        end
        `ALU_ADDU: begin
            sum = i_data1+i_data2;
            o_alu_out        = sum;
            o_alu_isOverflow = sum[32];
        end
        `ALU_SUBU: begin
            sum = i_data1-i_data2;
            o_alu_out        = sum;
            o_alu_isOverflow = sum[32];
        end
        `ALU_AND:
            o_alu_out        = i_data1 & i_data2;
        `ALU_OR:
            o_alu_out        = i_data1 | i_data2;
        `ALU_NOR:
            o_alu_out        = ~(i_data1 | i_data2);
        `ALU_BEQ:
            o_alu_hasBranch  = (i_data1==i_data2);
        `ALU_BNE:
            o_alu_hasBranch  = (i_data1!=i_data2);
        `ALU_SLT:
            o_alu_out        = (i_data1[31]>i_data2[31])||
                              (i_data1[31]==i_data2[31])&&(i_data1[30:0]<i_data2[30:0]);
    endcase        
end
endmodule
