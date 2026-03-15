module uart(
    input clk,
    input rst,
    input [31:0] addr,
    input [31:0] wdata,
    input we,
    output reg [31:0] rdata
);
    wire data_sel = (addr[3:2] == 2'b00);
    wire status_sel = (addr[3:2] == 2'b01);

    reg [7:0] tx_byte;
    reg tx_busy;
    reg [7:0] rx_byte;
    reg rx_ready;

    wire tx_ready = ~tx_busy;

    always @(posedge clk) begin
        if (rst) begin
            tx_byte <= 8'b0;
            tx_busy <= 1'b0;
            rx_byte <= 8'b0;
            rx_ready <= 1'b0;
        end else begin
            tx_busy <= 1'b0;
            if (we && data_sel) begin
                tx_byte <= wdata[7:0];
                tx_busy <= 1'b1;
                rx_byte <= wdata[7:0];  
                rx_ready <= 1'b1;
                $display("[uart] tx 0x%02x '%c'", wdata[7:0], wdata[7:0] >= 32 && wdata[7:0] < 127 ? wdata[7:0] : ".");
            end
            if (data_sel && ~we)
                rx_ready <= 1'b0;   
        end
    end

    always @(*) begin
        rdata = 32'h0;
        if (data_sel)
            rdata = {24'b0, rx_byte};
        else if (status_sel)
            rdata = {30'b0, rx_ready, tx_ready};
    end
endmodule
