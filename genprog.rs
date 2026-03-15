use std::{fs::File, io::Write};

// aes setup + run, then uart "Hi\n", then spin. last aes inst is jal to uart block.
const PROGRAM: [u32; 51] = [
    // aes: key/block/start, wait ready, read result to x18 (0x30..0x3c)
    0x000082b7, 0x00100313, 0x0062a023, 0x00200313, 0x0062a223, 0x00300313, 0x0062a423, 0x00400313,
    0x0062a623, 0x01028393, 0x00500313, 0x0063a023, 0x00600313, 0x0063a223, 0x00700313, 0x0063a423,
    0x00800313, 0x0063a623, 0x00100313, 0x0262a023, 0x0202a303, 0x00137313, 0xfe030ce3, 0x03028413,
    0x00042483, 0x00902023, 0x00442483, 0x00902223, 0x00842483, 0x00902423, 0x00c42483, 0x00902623,
    0x0040006f, // jal x0, +4 -> uart block
    // uart base x3=0x9000, status x4=0x9004; then "H" "i" "\n"
    0x000091b7, 0x00419193, 0x0001a303, 0x0013f313, 0xfe030ce3, 0x04800313, 0x0061a023,
    0x0001a303, 0x0013f313, 0xfe030ce3, 0x06900313, 0x0061a023,
    0x0001a303, 0x0013f313, 0xfe030ce3, 0x00a00313, 0x0061a023,
    0x0000006f, // j self
];

fn main() -> std::io::Result<()> {
    let mut bin = File::create("prog.bin")?;
    let mut hex = File::create("prog.hex")?;
    for inst in PROGRAM {
        bin.write_all(&inst.to_le_bytes())?;
        writeln!(hex, "{:08x}", inst)?;
    }
    Ok(())
}
