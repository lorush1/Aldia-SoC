module soc(
    input clk,
    input rst
);
    wire [31:0] cpu_pc;
    wire [31:0] cpu_instr;
    wire [31:0] cpu_addr;
    wire [31:0] cpu_wdata;
    wire cpu_we;
    rom rom_inst(
        .clk(clk),
        .addr(cpu_pc[11:2]),
        .rdata(cpu_instr)
    );
    cpu cpu_inst(
        .clk(clk),
        .rst(rst),
        .instr(cpu_instr),
        .rdata(bus_rdata),
        .addr(cpu_addr),
        .wdata(cpu_wdata),
        .we(cpu_we),
        .pc(cpu_pc)
    );
    wire ram_sel = cpu_addr < 32'h00008000;
    wire aes_sel = cpu_addr >= 32'h00008000 && cpu_addr < 32'h00009000;
    wire uart_sel = cpu_addr >= 32'h00009000 && cpu_addr < 32'h00009010;
    wire [31:0] ram_rdata;
    ram ram_inst(
        .clk(clk),
        .addr(cpu_addr[11:0]),
        .wdata(cpu_wdata),
        .we(ram_sel & cpu_we),
        .rdata(ram_rdata)
    );
    localparam [31:0] AES_BASE = 32'h00008000;
    localparam [31:0] KEY_LIMIT = 32'h00000010;
    localparam [31:0] BLOCK_LIMIT = 32'h00000020;
    localparam [31:0] CONTROL_OFFSET = 32'h00000020;
    localparam [31:0] RESULT_BASE = 32'h00000030;
    localparam [31:0] RESULT_LIMIT = 32'h00000040;
    wire [31:0] aes_offset = cpu_addr - AES_BASE;
    wire key_region = aes_offset < KEY_LIMIT;
    wire block_region = aes_offset >= KEY_LIMIT && aes_offset < BLOCK_LIMIT;
    wire control_region = aes_offset == CONTROL_OFFSET;
    wire result_region = aes_offset >= RESULT_BASE && aes_offset < RESULT_LIMIT;
    wire [31:0] key_local = aes_offset;
    wire [31:0] block_local = aes_offset - KEY_LIMIT;
    wire [31:0] result_local = aes_offset - RESULT_BASE;
    wire [1:0] key_word = key_local[3:2];
    wire [1:0] block_word = block_local[3:2];
    wire [1:0] result_word = result_local[3:2];
    wire write_aes = aes_sel && cpu_we;
    wire write_control = write_aes && control_region;
    reg [127:0] key_reg;
    reg [127:0] block_reg;
    reg [127:0] result_reg;
    reg start_req;
    reg prev_ready;
    wire aes_ready;
    wire [127:0] aes_block_out;
    aes aes_inst(
        .clk(clk),
        .start(start_req),
        .key(key_reg),
        .block_in(block_reg),
        .block_out(aes_block_out),
        .ready(aes_ready)
    );
    always @(posedge clk) begin
        if (rst) begin
            key_reg <= 128'b0;
            block_reg <= 128'b0;
            result_reg <= 128'b0;
            start_req <= 1'b0;
            prev_ready <= 1'b1;
        end else begin
            start_req <= write_control && cpu_wdata[0];
            if (write_aes && key_region)
                key_reg[key_word * 32 +: 32] <= cpu_wdata;
            if (write_aes && block_region)
                block_reg[block_word * 32 +: 32] <= cpu_wdata;
            if (aes_ready && !prev_ready)
                result_reg <= aes_block_out;
            prev_ready <= aes_ready;
        end
    end
    reg [31:0] aes_rdata;
    always @(*) begin
        aes_rdata = 32'h0;
        if (key_region)
            aes_rdata = key_reg[key_word * 32 +: 32];
        else if (block_region)
            aes_rdata = block_reg[block_word * 32 +: 32];
        else if (control_region)
            aes_rdata = {31'b0, aes_ready};
        else if (result_region)
            aes_rdata = result_reg[result_word * 32 +: 32];
    end
    wire [31:0] uart_rdata;
    uart uart_inst(
        .clk(clk),
        .rst(rst),
        .addr(cpu_addr),
        .wdata(cpu_wdata),
        .we(uart_sel & cpu_we),
        .rdata(uart_rdata)
    );
    wire [31:0] bus_rdata = ram_sel ? ram_rdata : (aes_sel ? aes_rdata : (uart_sel ? uart_rdata : 32'h0));
endmodule
