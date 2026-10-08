#!/bin/sh
set -eu
cd "$(dirname "$0")"
toolchain="$PWD/build/toolchain/usr"
cc="$toolchain/bin/riscv64-unknown-elf-gcc"
export PATH="$toolchain/bin:$PATH"
state="${1:-21345671111111}"
length="${2:-11}"
printf '#define INPUT_STATE "%s"\n#define EXPECTED_LENGTH %s\n' "$state" "$length" > build/reference_input.h
"$cc" -O2 -march=rv32i -mabi=ilp32 -ffreestanding -fno-builtin \
    -msmall-data-limit=0 -nostdlib -nostartfiles -Wl,--no-relax,-T,link.ld \
    -include build/reference_input.h -Wall -Wextra start.s reference.c -o build/reference.elf
"$toolchain/bin/riscv64-unknown-elf-size" -A build/reference.elf
"$toolchain/bin/riscv64-unknown-elf-gcc" -march=rv32i -mabi=ilp32 \
    -nostdlib -nostartfiles -Wl,--no-relax,-T,link.ld,-e,main solver.s -o build/solver.elf
"$toolchain/bin/riscv64-unknown-elf-size" -A build/solver.elf
"$toolchain/bin/riscv64-unknown-elf-objdump" -d build/solver.elf > build/solver.disassembly.txt
"$toolchain/bin/riscv64-unknown-elf-objdump" -d build/reference.elf > build/reference.disassembly.txt
