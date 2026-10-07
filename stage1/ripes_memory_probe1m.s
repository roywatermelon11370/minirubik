.text
.globl main
main:
    # Start at an unused guest-memory address.
    lui  t0, 0x20000          # t0 = 0x20000000

    # Number of bytes to touch: 0x100 = 1 MiB.
    lui  t1, 0x100            # t1 = 0x00100000

write_next_byte:
    sb   zero, 0(t0)          # Insert one guest byte into Ripes memory.
    addi t0, t0, 1
    addi t1, t1, -1
    bne  t1, zero, write_next_byte

    addi a7, zero, 10        # Ripes exit environment call.
    ecall
