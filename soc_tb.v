module soc_tb;
    reg clk = 0;
    reg rst = 1;

    always #5 clk = ~clk;

    soc dut (.clk(clk), .rst(rst));

    initial begin
        $display("aldia-soc sim: reset, then run. uart tx bytes show as [uart] tx ...");
        #20 rst = 0;
        #20000 $display("sim done.");
        $finish;
    end
endmodule
