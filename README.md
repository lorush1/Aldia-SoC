# aldia-soc

a small chip you can put on an fpga or run in a simulator. it has a tiny cpu, some ram, a rom for code, an aes block, and a minimal uart so the cpu can send (and receive) bytes over a serial line. run code that talks to aes and prints strings or results over the uart.

## what u get

- a minimal 32-bit cpu (handful of instructions, enough to load and store and do basic math)
- an instruction rom that preloads your program so the cpu fetches real code on reset instead of nops
- 4k of ram for data (code lives in rom)
- an aes-128 encryption block at 0x8000 so the cpu can feed it a key and a block and read back the result
- a uart at 0x9000: one tx register, a ready flag, one rx register—one byte per write/read, no baud logic, just enough to print strings or aes output (in sim, tx bytes show up in the log)

no operating system, no fancy toolchain just the core pieces. you write a small program (or use the example firmware), turn it into a binary, and the build spits out both the raw binary and a hex file the rom loads at build time.

## commands to run

build the program that makes the binary (you need rust):

```bash
cargo build --release
```

then run it to spit out `prog.bin` and `prog.hex`:

```bash
cargo run --release
```

that creates `prog.bin` (raw machine code) and `prog.hex` (same thing, one word per line for the rom). the rom in the rtl loads `prog.hex` at build time so when you simulate or synthesize, the cpu fetches your program from rom. change the program, run cargo run again, and the rom content updates. instruction fetches come from rom, ram and aes stay on the data bus unchanged.

to actually run the chip you need a verilog simulator (e.g. iverilog, verilator) or an fpga toolchain (e.g. vivado, quartus). there’s a minimal testbench (`soc_tb.v`) that runs the soc so you can see uart output in the sim log—after `cargo run --release`, compile and run with iverilog (see docs.md for the exact commands).

link to [technical docs](docs.md)

creds lorush1
