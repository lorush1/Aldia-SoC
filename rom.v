module rom(
    input clk,
    input [9:0] addr,
    output [31:0] rdata
);
    reg [31:0] mem [0:1023];
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'h00000013;
        $readmemh("prog.hex", mem);
    end
    assign rdata = mem[addr];
endmodule
