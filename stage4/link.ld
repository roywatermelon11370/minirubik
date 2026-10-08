ENTRY(_start)
SECTIONS {
    . = 0;
    .text : { *(.text.start) *(.text .text.*) }
    . = 0x10000000;
    .rodata : { *(.rodata .rodata.*) }
    .data : { *(.data .data.*) *(.sdata .sdata.*) }
    .bss : { *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) }
}
