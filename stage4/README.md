# Stage 4: RV32I coordinate solver

| File | Purpose |
| --- | --- |
| `solver.s` | Solver, runtime distance tables, and optional LED renderer |
| `tables.s` | Separate static quarter-turn tables and LED mappings |
| `solver.elf`, `solver-led.elf` | Ready-to-run console and LED executables |
| `generate_tables.c` | Regenerate tables from `../stage3/stage3_coordinates.c` |
| `link.ld`, `link.sh`, `build.ps1` | Build the two assembly files into an ELF |

## Run

Load the selected ELF as **Executable (ELF)** in Ripes. Choose `RV32_ISS`
or the 32-bit 5-stage processor, disable M/C extensions, and run.
Both supplied executables use input `21345671111111` and print:

```text
B' R' D2 R' B R B' R D2 B R'
PASS
```

For the LED version, manually add an LED Matrix with width **35**, height
**25**, and base **0xf0000000**. The delay is one million loop iterations
per move. A different input or peripheral base requires rebuilding.

## Build

`solver.s` and `tables.s` remain separate files. Use a GNU RISC-V toolchain
and set `RISCV_TOOLCHAIN` to its binary directory in Linux/WSL, or put its
`riscv64-unknown-elf-*` tools on PATH. From this folder:

```sh
sh link.sh
sh link.sh solver.s solver-led.elf 1 0xf0000000 1000000
```

The checked-in `tables.s` is sufficient for these commands. To regenerate
it and build from Windows, use host GCC, WSL, and the RISC-V toolchain:

```powershell
.\build.ps1
.\build.ps1 -Render -LedBase 0xf0000000
```

To change the input, edit `input_state` in `solver.s`; use
`expected_length=-1` unless the optimal length is known, then rebuild.
The generator's C arithmetic runs only on the host; the target ELF uses
RV32I with no multiply/divide/remainder instructions.

Tests and measurement records are omitted from this folder. The complete
working version remains in the workspace's `stage4_coordinates_rv32i`.
The implementation is AI-assisted; see `p76151571.md` for the disclosure.
