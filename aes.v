module aes(
    input clk,
    input start,
    input [127:0] key,
    input [127:0] block_in,
    output reg [127:0] block_out,
    output reg ready
);
    localparam [7:0] SBOX [0:255] = '{
        8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5, 8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe, 8'hd7, 8'hab, 8'h76,
        8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0, 8'had, 8'hd4, 8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0,
        8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7, 8'hcc, 8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15,
        8'h04, 8'hc7, 8'h23, 8'hc3, 8'h18, 8'h96, 8'h05, 8'h9a, 8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75,
        8'h09, 8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0, 8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3, 8'h2f, 8'h84,
        8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b, 8'h6a, 8'hcb, 8'hbe, 8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf,
        8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85, 8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8,
        8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92, 8'h9d, 8'h38, 8'hf5, 8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2,
        8'hcd, 8'h0c, 8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17, 8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19, 8'h73,
        8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88, 8'h46, 8'hee, 8'hb8, 8'h14, 8'hde, 8'h5e, 8'h0b, 8'hdb,
        8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c, 8'hc2, 8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79,
        8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5, 8'h4e, 8'ha9, 8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08,
        8'hba, 8'h78, 8'h25, 8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6, 8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a,
        8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e, 8'h61, 8'h35, 8'h57, 8'hb9, 8'h86, 8'hc1, 8'h1d, 8'h9e,
        8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94, 8'h9b, 8'h1e, 8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf,
        8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42, 8'h68, 8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16
    };

    localparam [7:0] RCON [1:10] = '{8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80, 8'h1b, 8'h36};
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN = 2'd1;
    localparam [1:0] DONE = 2'd2;
    reg [1:0] state = IDLE;
    reg [3:0] round = 4'd0;
    reg [127:0] state_data;
    reg [127:0] current_key;
    function [7:0] subbyte(input [7:0] value);
        subbyte = SBOX[value];
    endfunction
    function [7:0] mul2(input [7:0] value);
        mul2 = {value[6:0], 1'b0} ^ (8'h1b & {8{value[7]}});
    endfunction
    function [7:0] mul3(input [7:0] value);
        mul3 = mul2(value) ^ value;
    endfunction
    function [127:0] apply_sbox(input [127:0] data);
        reg [7:0] result [0:15];
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                result[i] = subbyte(data[127 - 8 * i -: 8]);
            apply_sbox = {result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
                          result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]};
        end
    endfunction
    function [127:0] shift_rows(input [127:0] data);
        reg [7:0] matrix [0:15];
        reg [7:0] shifted [0:15];
        integer i;
        integer row;
        integer col;
        integer src;
        begin
            for (i = 0; i < 16; i = i + 1)
                matrix[i] = data[127 - 8 * i -: 8];
            for (row = 0; row < 4; row = row + 1)
                for (col = 0; col < 4; col = col + 1) begin
                    src = ((col + row) & 2'd3) * 4 + row;
                    shifted[col * 4 + row] = matrix[src];
                end
            shift_rows = {shifted[0], shifted[1], shifted[2], shifted[3], shifted[4], shifted[5], shifted[6], shifted[7],
                          shifted[8], shifted[9], shifted[10], shifted[11], shifted[12], shifted[13], shifted[14], shifted[15]};
        end
    endfunction
    function [31:0] mix_column_single(input [31:0] column);
        reg [7:0] a0 = column[31:24];
        reg [7:0] a1 = column[23:16];
        reg [7:0] a2 = column[15:8];
        reg [7:0] a3 = column[7:0];
        reg [7:0] r0;
        reg [7:0] r1;
        reg [7:0] r2;
        reg [7:0] r3;
        begin
            r0 = mul2(a0) ^ mul3(a1) ^ a2 ^ a3;
            r1 = a0 ^ mul2(a1) ^ mul3(a2) ^ a3;
            r2 = a0 ^ a1 ^ mul2(a2) ^ mul3(a3);
            r3 = mul3(a0) ^ a1 ^ a2 ^ mul2(a3);
            mix_column_single = {r0, r1, r2, r3};
        end
    endfunction
    function [127:0] mix_columns(input [127:0] data);
        reg [31:0] column;
        reg [127:0] result;
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1) begin
                column = data[127 - 32 * i -: 32];
                result[127 - 32 * i -: 32] = mix_column_single(column);
            end
            mix_columns = result;
        end
    endfunction
    function [31:0] rot_word(input [31:0] word);
        rot_word = {word[23:0], word[31:24]};
    endfunction
    function [31:0] sub_word(input [31:0] word);
        sub_word = {subbyte(word[31:24]), subbyte(word[23:16]), subbyte(word[15:8]), subbyte(word[7:0])};
    endfunction
    function [127:0] key_schedule(input [127:0] previous, input [7:0] rc);
        reg [31:0] w0 = previous[127:96];
        reg [31:0] w1 = previous[95:64];
        reg [31:0] w2 = previous[63:32];
        reg [31:0] w3 = previous[31:0];
        reg [31:0] temp;
        begin
            temp = sub_word(rot_word(w3)) ^ {rc, 24'h0};
            w0 = w0 ^ temp;
            w1 = w1 ^ w0;
            w2 = w2 ^ w1;
            w3 = w3 ^ w2;
            key_schedule = {w0, w1, w2, w3};
        end
    endfunction
    wire [7:0] rcon_value = (round == 4'd0) ? 8'h00 : RCON[round];
    wire [127:0] sub_state = apply_sbox(state_data);
    wire [127:0] shifted = shift_rows(sub_state);
    wire [127:0] mixed = mix_columns(shifted);
    wire [127:0] round_key = key_schedule(current_key, rcon_value);
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                ready <= 1;
                if (start) begin
                    ready <= 0;
                    state <= RUN;
                    round <= 4'd1;
                    current_key <= key;
                    state_data <= block_in ^ key;
                end
            end
            RUN: begin
                current_key <= round_key;
                if (round == 4'd10) begin
                    state_data <= shifted ^ round_key;
                    block_out <= shifted ^ round_key;
                    ready <= 1;
                    state <= DONE;
                end else begin
                    state_data <= mixed ^ round_key;
                    round <= round + 4'd1;
                end
            end
            DONE: begin
                if (!start) begin
                    state <= IDLE;
                    round <= 4'd0;
                end
            end
        endcase
    end
endmodule
