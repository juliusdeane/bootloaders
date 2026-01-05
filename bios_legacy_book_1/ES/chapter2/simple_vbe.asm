[BITS 16]                  ; Modo real, 16bits
[ORG 0x7C00]               ; MBR en 0x7C00.

start:
    mov bx, 0x0101    ; 0x101 - 640x480
    call set_video_mode

    ; AX == 0x004F indica éxito (VESA)
    cmp ax, 0x004F
    jne .fallo

    mov si, modo_ok
    call print_string
    call wait_key

    mov bx, 0x0116    ; 0x116 - 1024x768
    call set_video_mode

    ; AX == 0x004F indica éxito (VESA)
    cmp ax, 0x004F
    jne .fallo

    call wait_key
    mov ax, 0x0003
    int 0x10

    mov si, modo_ret
    call print_string

    hlt
    jmp $

.fallo:
    ; En caso de fallo, volver a modo texto 3 y detenerse
    mov ax, 0x0003
    int 0x10

    mov si, modo_error
    call print_string

    hlt
    jmp $

set_video_mode:
    mov ax, 0x4F02
    or bx, 0x4000     ; MODE OR 0x4000 = 0x4+++ (pide LFB también)
    int 0x10
    ret

%include "bootloader_tools.asm"

modo_ok     db '[OK] Modo cambiado.', 13, 10, 0
modo_error  db '[ERROR] Error cambiando modo.', 13, 10, 0
modo_ret    db '[OK] Hemos vuelto a texto.', 13, 10, 0

times 510-($-$$) db 0x90   ; Pad con nop x 510 - tamaño del código.
dw 0xAA55
