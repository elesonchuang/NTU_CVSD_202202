`ifndef DEFINE_V
`define DEFINE_V
    // opcode definition
    `define OP_ADD  1
    `define OP_SUB  2
    `define OP_ADDU 3
    `define OP_SUBU 4
    `define OP_ADDI 5
    `define OP_LW   6
    `define OP_SW   7
    `define OP_AND  8
    `define OP_OR   9
    `define OP_NOR  10
    `define OP_BEQ  11
    `define OP_BNE  12
    `define OP_SLT  13
    `define OP_EOF  14
    // ALU operation
    `define ALU_ADD  1
    `define ALU_SUB  2
    `define ALU_ADDU 3    
    `define ALU_SUBU 4
    `define ALU_AND  5
    `define ALU_OR   6
    `define ALU_NOR  7
    `define ALU_BEQ  8
    `define ALU_BNE  9
    `define ALU_SLT  10
    // MIPS status definition
    `define R_TYPE_SUCCESS 0
    `define I_TYPE_SUCCESS 1
    `define MIPS_OVERFLOW 2
    `define MIPS_END 3
`endif
