[BITS 16]                  ; Modo real, 16bits
[ORG 0x7C00]               ; MBR en 0x7C00.

start:
    mov eax, 1

    mov si, mensaje
    call print_string
    jmp $

print_string:
    push ax
    push bx
    mov ah, 0x0e           ; BIOS teletype
.loop:
    lodsb                  ; Cargamos un byte desde [SI] en AL
    test al, al            ; ¿Es 0?
    jz .done               ; ¿Si es 0, jump a .done (hecho)
    ; Otra forma de hacerlo, con cmp.
    ; cmp al, 0
    ; je .done
    int 0x10               ; print
    jmp .loop
.done:
    pop bx
    pop ax
    ret

mensaje db 'Hola mundo!', 0

times 510-($-$$) db 0x90   ; Pad con nop x 510 - tamaño del código.

; MAGIC NUMBER para que la BIOS identifique el loader.
dw 0xAA55
