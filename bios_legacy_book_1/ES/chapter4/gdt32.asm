gdt_table:
    ; NULL descriptor
    dd 0
    dd 0
    ; Descriptor code 0: base=0, limit=0xFFFFF, code/rw, granularity
    dd 0x0000FFFF
    dd 0x00CF9A00
    ; Descriptor data 1: base=0, limit=0xFFFFF, data/rw
    dd 0x0000FFFF
    dd 0x00CF9200

gdt_ref:
    dw gdt_table_end - gdt_table - 1
    dd gdt_table

gdt_table_end:

