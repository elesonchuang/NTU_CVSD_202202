`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [3:0]   fn_sel;
output         busy;
output         valid;
output reg [127:0] iot_out;

localparam  S_IDLE      = 0,
            S_FETCHING  = 1,
            S_CALCULATE = 2,
            S_OUTPUT    = 3,
            S_OUTPUT_2  = 4;

localparam  F_MAX        = 4'd1,
            F_MIN        = 4'd2,
            F_TOP2MAX    = 4'd3,
            F_LAST2MIN   = 4'd4,
            F_AVG        = 4'd5,
            F_EXTRACT    = 4'd6,
            F_EXCLUDE    = 4'd7,
            F_PEAKMAX    = 4'd8,
            F_PEAKMIN    = 4'd9;

//some constant
localparam  IOT_MAX         = 128'hFF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF,
            LOW_EXTRACT     = 128'h6F_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF,
            HIGH_EXTRACT    = 128'hAF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF,
            LOW_EXCLUDE     = 128'h7F_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF,
            HIGH_EXCLUDE    = 128'hBF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF;

reg [2 : 0] carry_r, carry_w;
reg carry1_r, carry1_w;
reg [127 : 0] iot_buffer_r;
reg [127 : 0] output_buffer_w, output_buffer_r; //
reg [127 : 0] output_buffer2_w, output_buffer2_r; // top2/min2, also can be use for remember the last output

reg [2 : 0] state_w, state_r;
reg [3 : 0] counter_w, counter_r; // for iot_in assemble
reg [2 : 0] counter8_w, counter8_r; // for max / min


wire extract_valid = (state_r == S_OUTPUT) && ( (iot_buffer_r < HIGH_EXTRACT) && (iot_buffer_r > LOW_EXTRACT) );
wire exclude_valid = (state_r == S_OUTPUT) && ( (iot_buffer_r > HIGH_EXCLUDE) || (iot_buffer_r < LOW_EXCLUDE) );
wire peakmax_valid = (state_r == S_OUTPUT) && (output_buffer_r[127:0] > output_buffer2_r);
wire peakmin_valid = (state_r == S_OUTPUT) && (output_buffer_r[127:0] < output_buffer2_r);

wire max_en = iot_buffer_r > output_buffer_r;
wire min_en = iot_buffer_r < output_buffer_r;

wire clock_en = (state_r != S_FETCHING) || (fn_sel == F_AVG);


assign busy = (counter_r == 15) || rst || (counter8_r == 7 && state_r == S_CALCULATE) || (((fn_sel == F_TOP2MAX) || (fn_sel == F_LAST2MIN)) && state_r == S_OUTPUT);
assign valid =  (fn_sel == F_EXTRACT) ? (extract_valid):(
                (fn_sel == F_EXCLUDE) ? (exclude_valid):(
                (fn_sel == F_PEAKMAX) ? (peakmax_valid):(
                (fn_sel == F_PEAKMIN) ? (peakmin_valid):(
            (state_r == S_OUTPUT) || (state_r == S_OUTPUT_2)))));



// counter for iot data input
always @(*) begin
    case (state_r)
        S_FETCHING: begin
            counter_w = counter_r + 1;
            counter8_w = counter8_r;
        end
        S_IDLE: begin
            counter_w = 0;
            counter8_w = 0;
        end
        S_CALCULATE: begin
            counter_w = 0;
            counter8_w = counter8_r + 1;
        end
        S_OUTPUT: begin
            if ((fn_sel == F_TOP2MAX) || (fn_sel == F_LAST2MIN)) begin
                counter_w = counter_r;
                counter8_w = counter8_r;
            end else begin
                counter_w = 0;
                counter8_w = 0;
            end
        end
        S_OUTPUT_2: begin
            counter_w = 0;
            counter8_w = 0;
        end
        default: begin
            counter_w = 0;
            counter8_w = 0;
        end
    endcase
end
// FSM
always @(*) begin
    case (state_r)
        S_IDLE: 
            state_w = S_FETCHING;
        S_FETCHING: begin
            if (counter_r == 15) begin
                if ((fn_sel == F_EXTRACT) || (fn_sel == F_EXCLUDE)) begin
                    state_w = S_OUTPUT;
                end else begin
                    state_w = S_CALCULATE;
                end
            end
            else 
                state_w = S_FETCHING;
        end
        S_CALCULATE: begin
            if (counter8_r == 7)
                state_w = S_OUTPUT;
            else    
                state_w = S_FETCHING;
        end
        S_OUTPUT: begin // todo: output 2 values
            if ((fn_sel == F_TOP2MAX) || (fn_sel == F_LAST2MIN)) begin
                state_w = S_OUTPUT_2;
            end else begin
                state_w = S_FETCHING;
            end
        end
        S_OUTPUT_2:
            state_w = S_FETCHING;
        default: 
            state_w = S_IDLE;
    endcase
end


// input assemble
// always @(*) begin
//     iot_buffer_w = iot_buffer_r;
//     if (state_r == S_FETCHING) begin
//         iot_buffer_w
//     end
// end


//output logic
always @(*) begin
    output_buffer2_w = output_buffer2_r;
    output_buffer_w = output_buffer_r;
    carry_w = carry_r;
    carry1_w = carry1_r;
    if (state_r == S_FETCHING && fn_sel == F_AVG) begin
        if (counter_r == 15) begin
            {carry_w, output_buffer_w[127-:8]} = {carry_r, output_buffer_r[127-:8]} + iot_in + carry1_r;
            carry1_w = 0;
        end else begin
            {carry1_w, output_buffer_w[8*counter_r +: 8]} = output_buffer_r[8*counter_r +: 8] + iot_in + carry1_r;
        end
    end
    if (state_r == S_CALCULATE) begin
        case (fn_sel)
            F_MAX: if (max_en) output_buffer_w = iot_buffer_r;
            F_MIN: if (min_en) output_buffer_w = iot_buffer_r;
            F_TOP2MAX:begin
                if (max_en) begin
                    output_buffer_w = iot_buffer_r;
                    output_buffer2_w = output_buffer_r;
                end else if (iot_buffer_r > output_buffer2_r) begin
                    output_buffer2_w = iot_buffer_r;
                end
            end
            F_LAST2MIN:begin
                if (min_en) begin
                    output_buffer_w = iot_buffer_r;
                    output_buffer2_w = output_buffer_r;
                end else if (iot_buffer_r < output_buffer2_r) begin
                    output_buffer2_w = iot_buffer_r;
                end
            end
            // F_AVG: {carry_w , output_buffer_w} = {carry_r, output_buffer_r} + iot_buffer_r;
            F_PEAKMAX: if (max_en) output_buffer_w = iot_buffer_r;
            F_PEAKMIN: if (min_en) output_buffer_w = iot_buffer_r;

        endcase
    end else if (state_r == S_OUTPUT) begin // reset output_buffer
        case (fn_sel)
            F_MAX:      output_buffer_w = 0;
            F_MIN:      output_buffer_w = IOT_MAX;
            F_TOP2MAX:  output_buffer_w = 0;
            F_LAST2MIN: output_buffer_w = IOT_MAX;
            F_AVG: begin
                output_buffer_w = 0;
                carry_w = 0;
            end
            F_PEAKMAX:begin
                output_buffer_w = 0;
                if (peakmax_valid)
                    output_buffer2_w = output_buffer_r;
            end
            F_PEAKMIN:begin
                output_buffer_w = IOT_MAX;
                if (peakmin_valid)
                    output_buffer2_w = output_buffer_r;
            end
        endcase
    end else if (state_r == S_OUTPUT_2) begin //reset output_buffer 2 for TOP2MAX and LAST2MIN in each round
        case (fn_sel)
            F_TOP2MAX:  output_buffer2_w = 0;
            F_LAST2MIN: output_buffer2_w = IOT_MAX;
        endcase
    end else if (state_r == S_IDLE) begin // initialize
        case (fn_sel)
            F_MIN:begin
                output_buffer_w = IOT_MAX;
                output_buffer2_w = IOT_MAX;
            end
            F_LAST2MIN:begin
                output_buffer_w = IOT_MAX;
                output_buffer2_w = IOT_MAX;
            end
            F_PEAKMIN:begin
                output_buffer_w = IOT_MAX;
                output_buffer2_w = IOT_MAX;
            end
            default:begin
                output_buffer_w = 0;
                output_buffer2_w = 0;
            end
        endcase
    end
end

//mux of the final output
always @(*) begin
    iot_out = 0;
    if (state_r == S_OUTPUT) begin
        iot_out = output_buffer_r[127:0];
        case (fn_sel)
            F_AVG: iot_out = {carry_r, output_buffer_r[127:3]};
            F_EXCLUDE: iot_out = (exclude_valid) ? iot_buffer_r: 0;
            F_EXTRACT: iot_out = (extract_valid) ? iot_buffer_r: 0;
            F_PEAKMAX: iot_out = (peakmax_valid) ? output_buffer_r[127:0]: 0;
            F_PEAKMIN: iot_out = (peakmin_valid) ? output_buffer_r[127:0]: 0;
        endcase
    end else if (state_r == S_OUTPUT_2)
        iot_out = output_buffer2_r;
end

// sequential 

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state_r <= S_IDLE;       
        counter_r <= 0; 
        counter8_r <= 0;
        iot_buffer_r <= 0;

        carry_r <= 0;
        carry1_r <= 0;
    end
    else begin
        state_r     <= state_w;
        counter_r   <= counter_w;
        counter8_r  <= counter8_w;

        if (state_r == S_FETCHING)
            iot_buffer_r[8*counter_r +: 8] <= iot_in;
        else
            iot_buffer_r <= iot_buffer_r;

        if (fn_sel == F_AVG) begin
            carry_r <= carry_w;
            carry1_r <= carry1_w;
        end else begin
            carry_r <= carry_r;
            carry1_r <=carry1_r;
        end
        
    end 
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        output_buffer_r <= 0;
        output_buffer2_r <= 0;
    end else begin
        if (clock_en) begin
            output_buffer_r <= output_buffer_w;
            output_buffer2_r <= output_buffer2_w;
        end else begin
            output_buffer_r <= output_buffer_r;
            output_buffer2_r <= output_buffer2_r;
        end
    end
end
endmodule