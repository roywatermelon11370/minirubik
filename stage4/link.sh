#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
toolchain="${RISCV_TOOLCHAIN:-$PWD/../stage4_rv32i/build/toolchain/usr/bin}"
assembler="$toolchain/riscv64-unknown-elf-as"
linker="$toolchain/riscv64-unknown-elf-ld"
size="$toolchain/riscv64-unknown-elf-size"
objdump="$toolchain/riscv64-unknown-elf-objdump"
nm="$toolchain/riscv64-unknown-elf-nm"
solver="${1:-solver.s}"
output="${2:-solver.elf}"
render="${3:-0}"
led_base="${4:-0}"
led_delay="${5:-1000000}"
case "$render" in 0|1) ;; *) echo 'RENDER must be 0 or 1' >&2; exit 1 ;; esac
if [ "$render" = 1 ] && [ "$led_base" = 0 ]; then
    echo 'GUI build requires the actual LED_MATRIX_0_BASE exported by Ripes' >&2
    exit 1
fi
object_prefix="build/$(basename "$output")"
# Two translation units and two object files. No concatenation or combined .s.
"$assembler" -march=rv32i -mabi=ilp32 --defsym RENDER="$render" \
    --defsym LED_MATRIX_0_BASE="$led_base" --defsym LED_MATRIX_0_WIDTH=35 \
    --defsym LED_MATRIX_0_HEIGHT=25 --defsym LED_DELAY="$led_delay" \
    "$solver" -o "$object_prefix.solver.o"
"$assembler" -march=rv32i -mabi=ilp32 --defsym RENDER="$render" tables.s -o "$object_prefix.tables.o"
"$linker" -m elf32lriscv --no-relax -T link.ld -e main "$object_prefix.solver.o" "$object_prefix.tables.o" -o "$output"
"$objdump" -d -M no-aliases "$output" > "$output.disassembly.txt"
"$size" -A "$output" > "$output.sizes.txt"
"$nm" -u "$output" > "$output.undefined.txt"
test ! -s "$output.undefined.txt"
if grep -Eq '__mul|__div|__mod|\b(mul|mulh|mulhu|mulhsu|div|divu|rem|remu)\b' "$output.disassembly.txt"; then
    echo 'Forbidden arithmetic instruction or helper detected' >&2
    exit 1
fi
cat "$output.sizes.txt"
