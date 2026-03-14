# aldia-soc — technical docs

lower-level description of the blocks and how they fit together. all addresses and sizes in plain numbers where it helps.

---

## top level (soc.v)

one clock, one reset. the cpu drives the bus: address, write data, write enable. one shared read data line comes back. address space is split by range:

- addresses below `0x8000`: ram
- addresses `0x8000` and above: aes peripheral

instruction input to the cpu is currently tied to zero (no instruction memory in this design). so the cpu always sees a nop until you add a rom or load path for code.

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

## bus and wiring

- cpu always drives addr, wdata, we.
- ram is selected when addr < 0x8000; aes when addr >= 0x8000.
- ram write: ram_sel and cpu_we.
- aes writes: key and block regions by word index; control region for start.
- read mux: ram_sel -> ram_rdata; aes_sel -> aes_rdata; else 0.
- aes block is instantiated with key_reg, block_reg; result_reg is updated when aes_ready goes high after a run; result_region reads from result_reg.

---

## firmware / prog.bin

firmware.c shows the intended use: point at 0x8000, write the eight key words, then the eight block words (four for key, four for block in the code), then write 1 to the control word to start. then spin until ready and read result (not shown in the minimal example).

genprog.rs emits a fixed list of 32-bit instructions as prog.bin (little-endian). that binary is the machine code that would be loaded into instruction memory (or rom) for the cpu to execute. the current soc has no such path; it is intended to be added (e.g. rom or ram preload) when simulating or synthesizing.

creds lorush1