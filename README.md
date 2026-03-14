# aldia-soc

a small chip you can put on an fpga or run in a simulator. it has a tiny cpu, some ram, and a block that does aes encryption in hardware. the idea is you run code on the cpu that talks to the aes block to encrypt or decrypt data.

## what u get

- a minimal 32-bit cpu (handful of instructions, enough to load and store and do basic math)
- 4k of ram for code and data
- an aes-128 encryption block wired into the same address space so the cpu can feed it a key and a block of data and read back the result

no operating system, no fancy toolchain — just the core pieces. you write a small program (or use the example firmware), turn it into a binary, and that binary is what the cpu would run once you hook up instruction memory (or burn it into rom).

## commands to run

build the program that makes the binary (you need rust):

```bash
cargo build --release
```

then run it to spit out `prog.bin`:

```bash
cargo run --release
```

that creates `prog.bin` — the raw machine code. to actually run the chip you need a verilog simulator (e.g. iverilog, verilator) or an fpga toolchain (e.g. vivado, quartus). this repo only has the rtl and the program generator; it doesn’t include a simulation or synthesis script.

link to [technical docs](docs.md)

creds: lorush1
