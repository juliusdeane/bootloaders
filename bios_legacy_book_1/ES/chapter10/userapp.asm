;*****************************************************************************
; USERAPP.ASM - Programa de usuario en ring3
;*****************************************************************************
[BITS 64]
[ORG 0x600000]  ; Se cargará en 6MB

; Números de syscall
SYS_WRITE_SERIAL equ 1
SYS_EXIT         equ 2

_start:
    ; Mensaje 1
    mov rax, SYS_WRITE_SERIAL
    mov rdi, msg1
    mov rsi, msg1_len
    int 0x80

    ; Mensaje 2
    mov rax, SYS_WRITE_SERIAL
    mov rdi, msg2
    mov rsi, msg2_len
    int 0x80

    ; Mensaje 3 - con un bucle para demostrar múltiples syscalls
    mov rcx, 3          ; Repetir 3 veces
.loop:
    push rcx            ; Guardar contador

    mov rax, SYS_WRITE_SERIAL
    mov rdi, msg3
    mov rsi, msg3_len
    int 0x80

    pop rcx             ; Restaurar contador
    loop .loop          ; Decrementar rcx y saltar si != 0

    ; Mensaje final
    mov rax, SYS_WRITE_SERIAL
    mov rdi, msg4
    mov rsi, msg4_len
    int 0x80

    ; Salir con código 123
    mov rax, SYS_EXIT
    mov rdi, 123
    int 0x80

    ; No debería llegar aquí
.hang:
    hlt
    jmp .hang

;*****************************************************************************
; Datos
;*****************************************************************************
msg1: db 13, 10, '*** PROGRAMA DE USUARIO EN RING 3 ***', 13, 10, 0
msg1_len equ $ - msg1

msg2: db '[USER] Esto se ejecuta en Ring 3!', 13, 10, 0
msg2_len equ $ - msg2

msg3: db '[USER] Llamando syscall... ', 0
msg3_len equ $ - msg3

msg4: db 13, 10, '[USER] Terminando programa de usuario...', 13, 10, 0
msg4_len equ $ - msg4

;*****************************************************************************
; PADDING para hacer el binario de exactamente 512 bytes (1 sector)
;*****************************************************************************
times 512-($-$$) db 0
