module alu #(
    parameter INT_W  = 4,
    parameter FRAC_W = 6,
    parameter INST_W = 4,
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
); // Do not modify
    
localparam MIN = 10'b1000000000,
           MAX = 10'b0111111111;
// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
reg [DATA_W-1:0] o_data_w, o_data_r;
reg              o_valid_w, o_valid_r;
// ---- Add your own wires and registers here if needed ---- //
reg [3:0] cnt_w, cnt_r;
reg [DATA_W-1:0] pop_temp_w, pop_temp_r;
reg [3:0] pop_r, pop_w;

wire [DATA_W:0] sum, sub;
wire [1:0] overflow_check_sum, overflow_check_sub, overflow_check_mul, overflow_check_mac;
wire [DATA_W*2 - 1:0] mul_full, mac_full;
wire [DATA_W-1:0] mul, mul_round, mac, mac_round;
wire mul_MSB, mac_MSB;
wire [DATA_W-1:0] mul_output, mac_output;
// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_valid = o_valid_r;
assign o_data = o_data_r;
// sign extension by 1 bit
assign sub = {i_data_a[DATA_W-1], i_data_a} - {i_data_b[DATA_W-1], i_data_b}; 
assign sum = {i_data_a[DATA_W-1], i_data_a} + {i_data_b[DATA_W-1], i_data_b};

assign overflow_check_sum = sum[DATA_W -: 2];
assign overflow_check_sub = sub[DATA_W -: 2];

assign mul_full = i_data_a * i_data_b; // 20 bits full multiplication result
assign mul = mul_full[(DATA_W*2-1)-4 -: DATA_W]; // The 10 bits output, truncate the first 4 bits and the last 6 bits
assign mul_round = mul + 1; // the rounded result of multiplication
assign mul_MSB = mul_full[DATA_W*2-1]; // useful for checking overflow/underflow

assign overflow_check_mul = (mul_MSB == 0) ? ( // check if the truncated first 4 bits and the MSB of mul is the same
                            (mul_full[DATA_W*2-1 -: 5] == 5'b00000) ? (2'd0):(2'd1)
                            ):(
                            (mul_full[DATA_W*2-1 -: 5] == 5'b11111) ? (2'd0):(2'd2)
                            );

assign mul_output = (mul_full[0+:6] >= 6'b100000) ? ( // check if rounding is needed
                // handle the case that rounding cause overflow
                // ex: mul = 01_1111_1111 when the rounding is needed.
                // note that the negative value shouldn't encounter the rounding overflow,
                // since the most negative number that can be represented is an interger.
                    (mul_round[DATA_W-1] == 1 && mul[DATA_W-1] == 0) ? (MAX) : (mul_round)
                    ) : (mul) ;


assign mac_full = mul_full + { {4{o_data_r[DATA_W-1]}}, o_data_r, 6'b000000 }; 
assign mac = mac_full[(DATA_W*2-1)-4 -: DATA_W];
assign mac_round = mac + 1;
assign mac_MSB = mac_full[DATA_W*2-1]; // useful for checking overflow/underflow

assign overflow_check_mac = (mac_MSB == 0) ? ( // check if the truncated first 4 bits and the MSB of mul is the same
                            (mac_full[DATA_W*2-1 -: 5] == 5'b00000) ? (2'd0):(2'd1)
                            ):(
                            (mac_full[DATA_W*2-1 -: 5] == 5'b11111) ? (2'd0):(2'd2)
                            );

assign mac_output = (mac_full[0+:6] >= 6'b100000) ? ( // check if rounding is needed
                // handle the case that rounding cause overflow
                // ex: mac = 01_1111_1111 when the rounding is needed.
                // note that the negative value shouldn't encounter the rounding overflow,
                // since the most negative number that can be represented is an interger.
                    (mac_round[DATA_W-1] == 1 && mac[DATA_W-1] == 0) ? (MAX) : (mac_round)
                    ) : (mac) ;

// ---- Add your own wire data assignments here if needed ---- //



// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //
always@(*) begin
    if (i_valid) begin
        cnt_w = 0;
        pop_w = 0;
        pop_temp_w = 0;
        case (i_inst)
        4'b0000: begin //Signed Addition
            case (overflow_check_sum)
            2'b01: begin // overflow
                o_data_w = MAX;
                o_valid_w = 1'b1;
            end
            2'b10: begin // underflow
                o_data_w = MIN;
                o_valid_w = 1'b1;
            end
            default: begin
                o_data_w = sum[DATA_W-1:0];
                o_valid_w = 1'b1;
            end
            endcase
        end
        4'b0001: begin //Signed Subtraction
            case (overflow_check_sub)
            2'b01: begin // overflow
                o_data_w = MAX;
                o_valid_w = 1'b1;
            end
            2'b10: begin // underflow
                o_data_w = MIN;
                o_valid_w = 1'b1;
            end
            default: begin
                o_data_w = sub[DATA_W-1:0];
                o_valid_w = 1'b1;
            end
            endcase
        end
        4'b0010: begin //Signed Multiplication
            case (overflow_check_mul)
                2'b01: begin
                    o_data_w = MAX;
                    o_valid_w = 1'b1;
                end
                2'b10: begin
                    o_data_w = MIN;
                    o_valid_w = 1'b1;
                end
                default: begin
                    o_data_w = mul_output;
                    o_valid_w = 1'b1;
                end
            endcase
        end
        4'b0011: begin //MAC
            case (overflow_check_mac)
                2'b01: begin
                    o_data_w = MAX;
                    o_valid_w = 1'b1;
                end
                2'b10: begin
                    o_data_w = MIN;
                    o_valid_w = 1'b1;
                end     
                default: begin
                    o_data_w = mac_output;
                    o_valid_w = 1'b1;
                end
            endcase
        end
        4'b0100: begin //Tanh
            if (i_data_a >= $signed(10'b0001_100000)) begin //1.5
                o_data_w = 10'b0001_000000;
                o_valid_w = 1'b1;
            end else if (i_data_a >= $signed(10'b0000_100000)) begin //0.5
                case (i_data_a[0])
                    0: o_data_w = (i_data_a >> 1) + $signed(10'b0000_010000);
                    1: o_data_w = (i_data_a >> 1) + $signed(10'b0000_010001);
                endcase
                o_valid_w = 1'b1;
            end else if (i_data_a >= $signed(10'b1111_100000)) begin //-0.5
                o_data_w = i_data_a;
                o_valid_w = 1'b1;
            end else if (i_data_a >= $signed(10'b1110_100000)) begin //-1.5
                case (i_data_a[0])
                    0: o_data_w = ((i_data_a >>> 1) - $signed(10'b0000_010000));
                    1: o_data_w = ((i_data_a >>> 1) - $signed(10'b0000_010000)) + 1;
                endcase
                o_valid_w = 1'b1;
            end else begin
                o_data_w = 10'b1111_000000;
                o_valid_w = 1'b1;
            end
            
        end
        4'b0101: begin //ORN
        o_data_w = i_data_a | ~i_data_b;
        o_valid_w = 1'b1;
        end
        4'b0110: begin //Count leading zero bits
        case (1'b1)
            i_data_a[DATA_W-1]: begin
                o_data_w = 10'd0;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-2]: begin
                o_data_w = 10'd1;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-3]: begin
                o_data_w = 10'd2;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-4]: begin
                o_data_w = 10'd3;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-5]: begin
                o_data_w = 10'd4;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-6]: begin
                o_data_w = 10'd5;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-7]: begin
                o_data_w = 10'd6;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-8]: begin
                o_data_w = 10'd7;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-9]: begin
                o_data_w = 10'd8;
                o_valid_w = 1'b1;
            end
            i_data_a[DATA_W-10]: begin
                o_data_w = 10'd9;
                o_valid_w = 1'b1;
            end
            default: begin
                o_data_w = 10'd10;
                o_valid_w = 1'b1;
            end
        endcase 
        end
        4'b0111: begin //Count trailing zero bits
        case (1'b1)
            i_data_a[0]: begin
                o_data_w = 10'd0;
                o_valid_w = 1'b1;
            end
            i_data_a[1]: begin
                o_data_w = 10'd1;
                o_valid_w = 1'b1;
            end
            i_data_a[2]: begin
                o_data_w = 10'd2;
                o_valid_w = 1'b1;
            end
            i_data_a[3]: begin
                o_data_w = 10'd3;
                o_valid_w = 1'b1;
            end
            i_data_a[4]: begin
                o_data_w = 10'd4;
                o_valid_w = 1'b1;
            end
            i_data_a[5]: begin
                o_data_w = 10'd5;
                o_valid_w = 1'b1;
            end
            i_data_a[6]: begin
                o_data_w = 10'd6;
                o_valid_w = 1'b1;
            end
            i_data_a[7]: begin
                o_data_w = 10'd7;
                o_valid_w = 1'b1;
            end
            i_data_a[8]: begin
                o_data_w = 10'd8;
                o_valid_w = 1'b1;
            end
            i_data_a[9]: begin
                o_data_w = 10'd9;
                o_valid_w = 1'b1;
            end
            default: begin
                o_data_w = 10'd10;
                o_valid_w = 1'b1;
            end
        endcase
        end
        4'b1000: begin //Count set bits
        if (i_data_a[0] == 1'b1) 
            pop_w = 1'b1;
        else 
            pop_w = 1'b0;
        pop_temp_w = i_data_a >> 1;
        cnt_w = 1;
        o_valid_w = 1'b0;
        o_data_w = 0;
        end
        4'b1001: begin //Rotate left
            case (i_data_b)
                10'd0: o_data_w = {i_data_a[DATA_W-1:0]};
                10'd1: o_data_w = {i_data_a[DATA_W-2:0], i_data_a[DATA_W-1]};
                10'd2: o_data_w = {i_data_a[DATA_W-3:0], i_data_a[DATA_W-1:DATA_W-2]};
                10'd3: o_data_w = {i_data_a[DATA_W-4:0], i_data_a[DATA_W-1:DATA_W-3]};
                10'd4: o_data_w = {i_data_a[DATA_W-5:0], i_data_a[DATA_W-1:DATA_W-4]};
                10'd5: o_data_w = {i_data_a[DATA_W-6:0], i_data_a[DATA_W-1:DATA_W-5]};
                10'd6: o_data_w = {i_data_a[DATA_W-7:0], i_data_a[DATA_W-1:DATA_W-6]};
                10'd7: o_data_w = {i_data_a[DATA_W-8:0], i_data_a[DATA_W-1:DATA_W-7]};
                10'd8: o_data_w = {i_data_a[DATA_W-9:0], i_data_a[DATA_W-1:DATA_W-8]};
                10'd9: o_data_w = {i_data_a[0], i_data_a[DATA_W-1:DATA_W-9]};
                default: o_data_w = i_data_a;
            endcase
            o_valid_w = 1'b1;
        end
        default: begin 
        o_valid_w = 1'b0;
        o_data_w = 0;
        end
        endcase
    end else begin
        if (i_inst == 4'b1000)begin
            if (cnt_r == 4'd0) begin
                o_data_w = 0;
                cnt_w = 0;
                pop_temp_w = 0;
                pop_w = 0;
                o_valid_w = 1'b0;
            end else if (cnt_r != 4'd10) begin
                if (pop_temp_r[0] == 1'b1)
                    pop_w = pop_r + 1;
                else 
                    pop_w = pop_r;
                pop_temp_w = pop_temp_r >> 1;
                cnt_w = cnt_r + 1;
                o_valid_w = 1'b0;
                o_data_w = 0;
            end else if (cnt_r == 4'd10) begin
                o_data_w = pop_r;
                cnt_w = 0;
                pop_temp_w = 0;
                pop_w = 0;
                o_valid_w = 1'b1;
            end else begin
                o_data_w = 0;
                cnt_w = 0;
                pop_temp_w = 0;
                pop_w = 0;
                o_valid_w = 1'b0;
            end
        end else begin
            o_data_w = o_data_r;
            o_valid_w = 0;
            pop_w = 0;
            cnt_w = 0;
            pop_temp_w = 0;
        end
    end
end



// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always@(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        o_data_r <= 0;
        o_valid_r <= 0;
        cnt_r <= 0;
        pop_r <= 0;
        pop_temp_r <= 0;
    end else begin
        o_data_r <= o_data_w;
        o_valid_r <= o_valid_w;
        pop_r <= pop_w;
        pop_temp_r <= pop_temp_w;
        cnt_r <= cnt_w;
    end
end

endmodule