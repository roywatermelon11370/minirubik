.text
.globl main
main:
    # Reuse one aligned word so memory use stays approximately constant.
    lui  t0, 0x20000          # Address = 0x20000000
    sw   zero, 0(t0)          # Initialize the counter in guest memory.
    lui  t1, 0x40             # 0x40 << 12 = 262144 iterations

rate_loop:
    lw   t2, 0(t0)
    addi t2, t2, 1
    sw   t2, 0(t0)
    addi t1, t1, -1
    bne  t1, zero, rate_loop

    # At completion: t1 = 0; t2 and memory[0x20000000] = 262144.
    # Expected dynamic count: 3 setup + 5 * 262144 loop + 2 exit instructions.
    # Use Ripes --iret for the measured retired-instruction count.
    addi a7, zero, 10
    ecall
