[BITS 64]

; Constantes para COM1
COM1       equ 0x3F8
COM1_LSR   equ 0x3FD    ; Line Status Register


debug_string_64:
    push rax
    push rdx
.loop:
    lodsb               ; Cargar byte de [rsi] en al
    test al, al         ; ¿Es null?
    jz .done
    mov dx, COM1
    out dx, al
    jmp .loop
.done:
    pop rdx
    pop rax
    ret
