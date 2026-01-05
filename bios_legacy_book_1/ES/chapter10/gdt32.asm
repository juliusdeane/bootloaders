;*****************************************************************************
; BEGIN: inicio de la lógica de la GDT para 32 bits.
;*****************************************************************************
; Una GDT más preparada para Modo Protegido
align 8
gdt:
    ; Descriptor nulo
    dq 0x0000000000000000

gdt_code:
    ; Código: base=0, límite=4GB
    dw 0xFFFF       ; Límite 0-15
    dw 0x0000       ; Base 0-15 = 0
    db 0x00         ; Base 16-23 = 0
    db 0x9A         ; Present, Ring0, Code, Exec/Read
    db 0xCF         ; 4KB gran, 32-bit, límite alto
    db 0x00         ; Base 24-31 = 0

gdt_data:
    ; Datos: base=0, límite=4GB
    dw 0xFFFF       ; Límite 0-15
    dw 0x0000       ; Base 0-15 = 0
    db 0x00         ; Base 16-23 = 0
    db 0x92         ; Present, Ring0, Data, R/W
    db 0xCF         ; 4KB gran, 32-bit, límite alto
    db 0x00         ; Base 24-31 = 0

gdt_ref:
    dw gdt_end - gdt - 1
    dd gdt
gdt_end:
;*****************************************************************************
; //END: fin de la lógica de la GDT.
;*****************************************************************************
