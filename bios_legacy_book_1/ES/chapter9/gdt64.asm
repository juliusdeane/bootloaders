gdt64:
    dq 0                    ; null descriptor
.code: equ $ - gdt64
    dq 0x00209A0000000000   ; código 64-bit
.data: equ $ - gdt64
    dq 0x0000920000000000   ; datos 64-bit

gdt64_ptr:
    dw $ - gdt64 - 1
    dd gdt64
