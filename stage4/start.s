.section .text.start
.globl _start
_start:
    lui sp, 0x20000
    call reference_main
    li a0, 1
    li a7, 93
    ecall
