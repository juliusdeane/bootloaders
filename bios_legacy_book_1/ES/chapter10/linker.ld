ENTRY(kernel_entry)
SECTIONS {
  . = 0x300000;
  .text : {
    *(.text.entry)
    *(.text)
  }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss) }
  . = 0x600000;
  .usercode : { *(.usercode) }
}
