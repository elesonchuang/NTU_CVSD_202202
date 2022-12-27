module reg_file(                            
    input               i_clk, 
    input               i_rst_n, 
    input  [4:0]  i_read_addr1,
    input  [4:0]  i_read_addr2,
    output [31:0] o_read_data1,
    output [31:0] o_read_data2,

    input         i_needWrite,
    input  [4:0]  i_write_addr,
    input  [31:0] i_write_data
);

reg  [31:0] mem_r [0:31];
integer i;

assign o_read_data1 = mem_r[i_read_addr1];
assign o_read_data2 = mem_r[i_read_addr2];

always@(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        for(i=0;i<32;i=i+1)
            mem_r[i] <= 0;
    end
    else if(i_needWrite)
            mem_r[i_write_addr] <= i_write_data;
end
endmodule
