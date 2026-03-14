module ram(input clk,input [11:0] addr,input [31:0] wdata,input we,output reg [31:0] rdata);
reg [31:0] mem [0:1023];
always @(posedge clk) begin
    if(we) mem[addr[11:2]]<=wdata;
    rdata<=mem[addr[11:2]];
end
endmodule
