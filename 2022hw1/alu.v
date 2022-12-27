module alu #(
    parameter INT_W  = 3,
    parameter FRAC_W = 5,
    parameter INST_W = 3,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                     i_clk,
    input                     i_rst_n,
    input                     i_valid,
    input signed [DATA_W-1:0] i_data_a,
    input signed [DATA_W-1:0] i_data_b,
    input        [INST_W-1:0] i_inst,
    output                    o_valid,
    output       [DATA_W-1:0] o_data
);
    
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
reg  [DATA_W:0] o_data_w, o_data_r;
reg             o_valid_w, o_valid_r;
// ---- Add your own wires and registers here if needed ---- //


// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;
// ---- Add your own wire data assignments here if needed ---- //


// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your combinational block design here ---- //
always@(*) begin
    case(i_inst)
        3'b000: o_data_w = add_test(i_data_a, i_data_b);
        3'b001: o_data_w = add_test(i_data_a, ((~i_data_b)+1));
        3'b010: o_data_w = mult_test(i_data_a, i_data_b); 
        3'b011: o_data_w = ~(i_data_a&i_data_b);
        3'b100: o_data_w = ~(i_data_a^i_data_b);
        3'b101: o_data_w = sigmoid_test(i_data_a);
        3'b110: o_data_w = shift_test(i_data_a, i_data_b);
        3'b111: o_data_w = ((i_data_a>i_data_b)?i_data_b:i_data_a);
    endcase
    o_valid_w = 1'b1;   
end

function[DATA_W-1:0] add_test;
    input [DATA_W-1:0] i_data_a;
    input [DATA_W-1:0] i_data_b;
    reg   [DATA_W-1:0] tmp;
    begin
        tmp = i_data_a+i_data_b;
        if(i_data_a[DATA_W-1]!=i_data_b[DATA_W-1]) begin
            add_test = tmp; 
        end
        else  if(i_data_a[DATA_W-1]==tmp[DATA_W-1]) begin
            add_test = tmp;
        end
        else if(i_data_a[DATA_W-1]==0) begin
            add_test = 8'b01111111;
        end
        else begin
            add_test = 8'b10000000;
        end
    end
endfunction

function [DATA_W-1:0] mult_test;
    input [DATA_W-1:0] i_data_a;
    input [DATA_W-1:0] i_data_b;
    reg   [DATA_W-1+DATA_W:0] direct_mult;
    reg   [DATA_W-1+FRAC_W:0] tmp;
    reg                       bit;
    reg                       is2comp;
    integer                   idx;

    begin
        bit = 0;
        if(i_data_a[DATA_W-1]==1) begin
            bit = !bit;
            i_data_a = ~(i_data_a)+1;
        end
        if(i_data_b[DATA_W-1]==1) begin
            bit = !bit;
            i_data_b = ~(i_data_b)+1;
        end
        direct_mult = {8'b00000000, i_data_a}*{8'b00000000, i_data_b};
       
        if(bit==1) begin
            is2comp = 0;
            for(idx=2*DATA_W-1; idx>=0; idx=idx-1) begin
                if(is2comp==0 && direct_mult[idx]==1) begin
                    is2comp=1;
                    direct_mult[idx+1] = 1;
                end
                if(is2comp==1)
                    direct_mult[idx] = ~direct_mult[idx];
            end
        end        

        if(direct_mult[2*DATA_W-1]==0&&direct_mult[2*DATA_W-2]==0&&direct_mult[2*DATA_W-3]==0) begin
            tmp = direct_mult[DATA_W-1+FRAC_W:0];
            mult_test = tmp[DATA_W-1+FRAC_W:FRAC_W]+((tmp[FRAC_W-1:0]>15)?1:0);
        end
        else if(direct_mult[2*DATA_W-1]==0) begin
            mult_test = 8'b01111111;
        end
        else begin
            mult_test = 8'b10000000;
        end
    end
endfunction

function  [DATA_W-1:0] sigmoid_test;
    input [DATA_W-1:0] i_data_a;
    integer            i_value_a;
    reg   [DATA_W-1:0] tmp;
    begin
        if(i_data_a[DATA_W-1]==0)
            i_value_a = i_data_a;
        else
            i_value_a = i_data_a[DATA_W-2:0]-(1<<(DATA_W-1));            

        if(i_value_a>=64)
            sigmoid_test = 8'b00100000;
        else if(i_value_a<=-64)
            sigmoid_test = 8'b00000000;
        else begin
            tmp = i_value_a+64;
            sigmoid_test = tmp[DATA_W-1:2];
        end
    end
endfunction

function  [DATA_W-1:0] shift_test;
    input [DATA_W-1:0] i_data_a;
    input [DATA_W-1:0] i_data_b;
    integer            shift_amount;
    integer            idx;
    begin
        shift_amount = i_data_b%DATA_W;
        for(idx=0; idx<DATA_W; idx=idx+1) begin
            shift_test[idx] = i_data_a[(idx+shift_amount)%DATA_W];
        end
    end
endfunction
//

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always@(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        o_data_r  <= 0;
        o_valid_r <= 0;
    end else begin
        o_data_r  <= o_data_w;
        o_valid_r <= o_valid_w;
    end
end
endmodule
