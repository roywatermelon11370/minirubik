#!/bin/sh
# POSIX shell runner for WSL and Linux. Run with sh; chmod is not required.
set -eu

benchmark=0
case "${1:-}" in
    "") ;;
    --benchmark) benchmark=1; shift ;;
    --help|-h)
        printf 'Usage: sh verify-stage3.sh [--benchmark]\n'
        exit 0
        ;;
    *)
        printf 'Unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac
if [ "$#" -ne 0 ]; then
    printf 'Usage: sh verify-stage3.sh [--benchmark]\n' >&2
    exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir="$script_dir/build/linux"
vectors="$script_dir/../tests/solutions.txt"
compiler=${CC:-cc}
if ! command -v "$compiler" >/dev/null 2>&1; then
    printf 'C compiler not found: %s (install GCC or set CC=clang).\n' "$compiler" >&2
    exit 1
fi
mkdir -p "$build_dir"
expected=$(mktemp)
actual=''
trap 'rm -f -- "$expected" "$actual"' 0
trap 'exit 1' HUP INT TERM
actual=$(mktemp)
cr=$(printf '\r')

assert_status()
{
    expected_status=$1
    shift
    if "$@" >/dev/null 2>&1; then
        actual_status=0
    else
        actual_status=$?
    fi
    if [ "$actual_status" -ne "$expected_status" ]; then
        printf '%s: expected exit %s, got %s\n' "$*" "$expected_status" "$actual_status" >&2
        return 1
    fi
}

assert_closed_stdout()
{
    if "$@" >&- 2>/dev/null; then
        actual_status=0
    else
        actual_status=$?
    fi
    if [ "$actual_status" -ne 1 ]; then
        printf '%s with stdout closed: expected exit 1, got %s\n' "$*" "$actual_status" >&2
        return 1
    fi
}

for variant in stage2_baseline stage3_coordinates; do
    binary="$build_dir/$variant"
    "$compiler" -O3 -std=c99 -Wall -Wextra -Wpedantic \
        "$script_dir/$variant.c" -o "$binary"
    "$binary" --self-test
    count=0
    while IFS= read -r line || [ -n "$line" ]; do
        # Inputs may have Windows CRLF endings on /mnt/c.
        line=${line%"$cr"}
        case "$line" in
            ""|\#*) continue ;;
            *'|'*) ;;
            *) printf 'Malformed solution vector: %s\n' "$line" >&2; exit 1 ;;
        esac
        state=${line%%|*}
        solution=${line#*|}
        printf '%s\n' "$solution" >"$expected"
        if ! "$binary" "$state" >"$actual"; then
            printf '%s: solving %s failed\n' "$variant" "$state" >&2
            exit 1
        fi
        if ! cmp -s "$expected" "$actual"; then
            printf '%s: solution mismatch for %s\nExpected:\n' "$variant" "$state" >&2
            cat "$expected" >&2
            printf 'Actual:\n' >&2
            cat "$actual" >&2
            exit 1
        fi
        count=$((count + 1))
    done <"$vectors"
    if [ "$count" -eq 0 ]; then
        printf 'No solution vectors found.\n' >&2
        exit 1
    fi

    for state in \
        1234567111111 123456711111111 02345671111111 \
        82345671111111 12345671111110 12345671111114 \
        1234567111111a 11345671111111 12345671111112; do
        assert_status 2 "$binary" "$state"
    done
    assert_status 2 "$binary"
    assert_status 2 "$binary" 12345671111111 12345671111111
    assert_closed_stdout "$binary" 21345671111111
    assert_closed_stdout "$binary" --self-test
    printf '%s: self-test, %s solution vectors, invalid inputs, and closed stdout passed.\n' \
        "$variant" "$count"
done

if [ "$benchmark" -eq 1 ]; then
    printf '\nHost CPU timings (each input repeated 100 times; excludes process startup).\n'
    for variant in stage2_baseline stage3_coordinates; do
        binary="$build_dir/${variant}_benchmark"
        "$compiler" -O3 -std=c99 -Wall -Wextra -Wpedantic \
            "-DVARIANT=$variant.c" "$script_dir/benchmark.c" -o "$binary"
        printf '\n%s\n' "$variant"
        "$binary"
    done
fi
