[BITS 16]


vbe_controller_info:
    push ax
    push bx
    push di
    push es

    mov ax, 0x4F00
    mov di, vbe_ctrl_info
    xor bx, bx
    mov es, bx
    int 0x10

    cmp ax, 0x004F    ; AX==0x004F success? (AX==0x004F or AL==0x4F?)
    ; check AL/AX per implementacion: spec devuelve AX=0x004F on success
    jnz .vbe_fail

    pop es
    pop di
    pop bx
    pop ax
    ret

.vbe_fail:
    ; procesar el error.
    pop es
    pop di
    pop bx
    pop ax
    ret

vbe_pm_information:
    push ax
    push bx
    push di
    push es

    mov ax, 0x4F0A
    xor bx, bx
    mov es, bx
    mov di, vbe_pm_info
    int 0x10
    cmp ax, 0x004F
    jnz .no_pm_interface

    pop es
    pop di
    pop bx
    pop ax
    ret

.no_pm_interface:
; Manejar el error.
    pop es
    pop di
    pop bx
    pop ax
    ret

; Corresponde a VideoModePtr:
vbe_ctrl_info: times 512 db 0

; Es MUY importante que este buffer esté por debajo de 1MB.
; Corresponde a PMInfoBlock:
vbe_pm_info: times 256 db 0
