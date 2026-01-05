[BITS 32]

; Constantes para COM1
COM1       equ 0x3F8
COM1_LSR   equ 0x3FD    ; Line Status Register

;*****************************************************************************
; Inicializar COM1 (en caso de no haberlo hecho en 16b)
;*****************************************************************************
init_com1:
    push ax
    push dx

    ; Deshabilitar interrupciones
    mov dx, COM1 + 1
    mov al, 0x00
    out dx, al

    ; Habilitar DLAB (Divisor Latch Access Bit)
    mov dx, COM1 + 3
    mov al, 0x80
    out dx, al

    ; Configurar velocidad: 38400 bps (divisor = 3)
    mov dx, COM1
    mov al, 0x03        ; Divisor bajo
    out dx, al
    mov dx, COM1 + 1
    mov al, 0x00        ; Divisor alto
    out dx, al

    ; 8 bits, sin paridad, 1 bit de parada
    mov dx, COM1 + 3
    mov al, 0x03
    out dx, al

    ; Habilitar FIFO, limpiar buffers
    mov dx, COM1 + 2
    mov al, 0xC7
    out dx, al

    ; Habilitar RTS/DSR
    mov dx, COM1 + 4
    mov al, 0x0B
    out dx, al

    pop dx
    pop ax
    ret

;*****************************************************************************
; Enviar UN carácter por COM1
; - AL = carácter a enviar
;*****************************************************************************
putc_serial:
    push edx
    push eax

.wait:
    mov dx, COM1_LSR    ; Line Status Register
    in al, dx
    test al, 0x20       ; ¿Buffer vacío?
    jz .wait

    pop eax
    mov dx, COM1
    out dx, al

    pop edx
    ret

;*****************************************************************************
; Enviar una cadena de texto por COM1
; - ESI = texto a enviar
;*****************************************************************************
puts_serial:
    push eax
    push esi

.loop:
    mov al, [esi]
    test al, al
    jz .done

    call putc_serial
    inc esi
    jmp .loop

.done:
    pop esi
    pop eax
    ret


;*****************************************************************************
; DEBUG en HEXADECIMAL utilizando la consola serial.
; - contenido de EBX en texto en COM1.
; - formato: 0x<valor>
;*****************************************************************************
print_hex_serial:
    pusha

    ; Imprimir "0x"
    mov al, '0'
    call putc_serial
    mov al, 'x'
    call putc_serial

    mov ecx, 8      ; 8 dígitos hex (32 bits)
.digit:
    rol ebx, 4
    mov al, bl
    and al, 0x0F

    cmp al, 9
    jbe .numero
    add al, 'A' - 10
    jmp .imprimir
.numero:
    add al, '0'
.imprimir:
    call putc_serial
    dec ecx
    jnz .digit

    popa
    ret

;*****************************************************************************
; Enviar un SALTO DE LÍNEA por COM1
;*****************************************************************************
serial_crlf:
    push eax

    mov al, 0x0D
    call putc_serial
    mov al, 0x0A
    call putc_serial

    pop eax
    ret
