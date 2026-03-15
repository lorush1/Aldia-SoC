# aldia-soc — technical docs

lower-level description of the blocks and how they fit together. all addresses and sizes in plain numbers where it helps.

---

## top level (soc.v)

one clock, one reset. the cpu has two paths: instruction fetch and data bus. instruction fetch goes to a rom (see below). the cpu drives the data bus: address, write data, write enable. one shared read data line comes back. address space is split by range:

- addresses below `0x8000`: ram
- `0x8000`–`0x8fff`: aes peripheral
- `0x9000`–`0x900f`: uart peripheral

instruction input to the cpu comes from the rom, addressed by the cpu pc. on reset the cpu fetches from rom so it runs your program instead of nops.

---

## cpu (cpu.v)

single-cycle style, 32-bit, 32 general-purpose registers (x0 is zero). no pipeline.

**instruction formats (riscv-like)**

- r-type: opcode, rd, funct3, rs1, rs2, funct7 — for register–register ops
- i-type: opcode, rd, funct3, rs1, imm[11:0] — for addi, load
- s-type: opcode, imm (split), funct3, rs1, rs2 — for store
- b-type: opcode, imm (split), funct3, rs1, rs2 — for branch

**decoded operations**

- `add` — rd = rs1 + rs2 (funct3=0, funct7=0)
- `sub` — rd = rs1 - rs2 (funct3=0, funct7=0x20)
- `xor` — rd = rs1 ^ rs2 (funct3=4)
- `addi` — rd = rs1 + sign-extended imm (funct3=0)
- `lw` — rd = mem[rs1 + imm] word load (funct3=2)
- `sw` — mem[rs1 + imm] = rs2 word store (funct3=2)
- `beq` — if rs1 == rs2 then pc += imm (funct3=0)

alu is used for address and for arithmetic. load uses the same alu output as address; store uses it for address and rs2 for write data. write-back happens for add, sub, xor, addi, lw (and rd must not be 0). branch uses a dedicated comparison and adds the sign-extended b-type immediate to pc.

---

## rom (rom.v)

instruction memory. word-addressed, 1024 words (4k instructions). synchronous block but combinational read so the cpu gets the instruction in the same cycle as pc, no pipeline. contents come from `prog.hex` at build time via `$readmemh`. any word not in the file is nop (0x00000013). the program generator (genprog.rs) writes both `prog.bin` and `prog.hex` when you run it, so building the program updates the rom. in the soc, the rom is connected to the cpu pc (word index = pc[11:2]) and its output is the cpu instr input. ram and aes are unchanged on the data bus.

---

## ram (ram.v)

single block ram: 1024 words of 32 bits (4 kb). byte address is used with `addr[11:2]` so it is word-addressed internally. one read and one write per cycle; write is gated by `we`. read data is registered (one cycle latency).

in the soc, writes to ram only happen when the bus address is in the ram range and the cpu is doing a store.

---

## aes block (aes.v)

aes-128 encryption. one 128-bit key, one 128-bit input block, one 128-bit output block. start/ready handshake.

**state machine**

- idle: ready high, waits for start high
- run: 10 rounds of aes (subbytes, shiftrows, mixcolumns except last round, addroundkey). one round per clock.
- done: result latched, ready high until start goes low, then back to idle

**internals**

- sbox: 256-byte lookup table, standard aes s-box
- rcon: 10 bytes for key schedule
- subbyte: byte through sbox
- shift rows: standard aes row shifts
- mix columns: gf(2^8) with poly 0x1b, mul2/mul3 helpers
- key schedule: rotword, subword, xor with rcon; one round key per clock in run

---

## aes memory map (soc.v)

base address `0x8000`. all registers 32 bits; key, block, and result are accessed as four words each (little-endian word order).

| offset | size   | use |
|--------|--------|-----|
| 0x00   | 4 words| key [127:0] |
| 0x10   | 4 words| input block [127:0] |
| 0x20   | 1 word | control: bit 0 = start (write 1 to run), read = {31’b0, ready} |
| 0x30   | 4 words| result [127:0] (read-only) |

key and block are written by the cpu; writing the control word with bit 0 set starts encryption. when ready is high the cpu can read the result from the result words. result is captured when the aes core goes from not ready to ready.

---

## uart (uart.v)

minimal serial port so the cpu can send and receive bytes. one transmit register, a ready flag, and one receive register. one byte per write or read cycle; no baud rate or real serial line in this block—just the bus interface (in sim, tx bytes are printed with `$display` and rx loopbacks from tx for demo).

**uart memory map (base 0x9000)**

| offset | size   | use |
|--------|--------|-----|
| 0x00   | 1 word | data: write = send byte (low 8 bits), read = last received byte |
| 0x04   | 1 word | status (read-only): bit 0 = tx_ready (1 = can write next byte), bit 1 = rx_ready (1 = byte available) |

to send a byte: poll status until tx_ready is 1, then store the byte to data. to receive: poll status until rx_ready is 1, then load from data (reading clears rx_ready for the next byte).

---

## bus and wiring

- instruction fetch: cpu pc (word index pc[11:2]) goes to rom, rom output is cpu instr. no data bus involved.
- data bus: cpu always drives addr, wdata, we.
- ram when addr < 0x8000; aes when 0x8000 ≤ addr < 0x9000; uart when 0x9000 ≤ addr < 0x9010.
- ram write: ram_sel and cpu_we.
- aes writes: key and block regions by word index; control region for start.
- uart write: uart_sel and cpu_we; data register at 0x9000, status at 0x9004.
- read mux: ram_sel → ram_rdata; aes_sel → aes_rdata; uart_sel → uart_rdata; else 0.
- aes block is instantiated with key_reg, block_reg; result_reg is updated when aes_ready goes high after a run; result_region reads from result_reg.

---

## firmware / prog.bin / prog.hex

firmware.c shows the intended use: run aes (key/block at 0x8000, start, wait ready), then print over uart (write bytes to 0x9000 after polling tx_ready at 0x9004). you can also send aes result bytes to the uart for debugging.

genprog.rs emits a fixed list of 32-bit instructions as prog.bin (little-endian) and prog.hex (one word per line, hex, for the rom). when you run cargo run, both files are written. the rom loads prog.hex at build time so the cpu runs that code. change the program, run the generator again, rom content updates.

**simulation:** soc_tb.v runs the soc for a fixed time; the uart uses `$display` so bytes sent to 0x9000 show up in the sim log (e.g. "Hi" after aes). run `cargo run --release` to get prog.hex, then with iverilog: `iverilog -o soc_sim.vvp soc_tb.v soc.v cpu.v rom.v ram.v uart.v aes.v` and `vvp soc_sim.vvp`.

creds lorush1