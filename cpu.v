module cpu(
    input clk,
    input rst,
    input [31:0] instr,
    input [31:0] rdata,
    output reg [31:0] addr,
    output reg [31:0] wdata,
    output reg we,
    output reg [31:0] pc
);
    reg [31:0] regs [0:31];
    integer i;
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [6:0] funct7 = instr[31:25];
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire is_add = opcode == 7'b0110011 && funct3 == 3'b000 && funct7 == 7'b0000000;
    wire is_sub = opcode == 7'b0110011 && funct3 == 3'b000 && funct7 == 7'b0100000;
    wire is_xor = opcode == 7'b0110011 && funct3 == 3'b100;
    wire is_addi = opcode == 7'b0010011 && funct3 == 3'b000;
    wire is_lw = opcode == 7'b0000011 && funct3 == 3'b010;
    wire is_sw = opcode == 7'b0100011 && funct3 == 3'b010;
    wire is_beq = opcode == 7'b1100011 && funct3 == 3'b000;
    wire [31:0] alu_second = is_addi || is_lw ? imm_i : is_sw ? imm_s : regs[rs2];
    wire [31:0] sum = regs[rs1] + alu_second;
    wire [31:0] sub = regs[rs1] - regs[rs2];
    wire [31:0] xor_ = regs[rs1] ^ regs[rs2];
    wire [31:0] alu_out = is_sub ? sub : is_xor ? xor_ : sum;
    wire branch_taken = is_beq && regs[rs1] == regs[rs2];
    wire [31:0] next_pc = (branch_taken ? pc + imm_b : pc + 4);
    wire write_reg = is_add || is_sub || is_xor || is_addi || is_lw;
    wire [31:0] write_data = is_lw ? rdata : alu_out;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 0;
    end
    always @(*) begin
        addr = alu_out;
        wdata = regs[rs2];
        we = is_sw;
    end
    always @(posedge clk) begin
        if (rst) begin
            pc <= 0;
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 0;
        end else begin
            pc <= next_pc;
            if (write_reg && rd != 0)
                regs[rd] <= write_data;
        end
    end
endmodule
