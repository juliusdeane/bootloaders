
; Print cadena de texto.
print_string16:
    pusha

    mov ah, 0x0e        ; Teletype output
.pr16_loop:
    lodsb               ; Load byte from SI into AL
    cmp al, 0           ; Check for null terminator
    je .pr16_done
    int 0x10            ; Print character
    jmp .pr16_loop

.pr16_done:
    popa
    ret

; Imprimir punto.
print_dot:
    pusha                       ; Guardar todos los registros (necesario para la llamada INT 10h)

    mov ah, 0x0e                ; Función Teletipo (Escribir carácter en cursor)
    mov al, '.'                 ; Carácter a escribir (ASCII 46)
    int 0x10                    ; Llamar a la BIOS (Real Mode)

    popa                        ; Restaurar registros
    ret


print_hex_byte:
    push ax

    ; Imprimir nibble alto
    mov ah, al
    shr al, 4               ; Obtener los 4 bits altos
    call print_hex_digit

    ; Imprimir nibble bajo
    mov al, ah
    and al, 0x0F            ; Obtener los 4 bits bajos
    call print_hex_digit

    pop ax
    ret


print_hex_word:
    push ax

    ; Imprimir byte alto
    mov al, ah
    call print_hex_byte

    ; Imprimir byte bajo
    pop ax
    push ax
    call print_hex_byte

    pop ax
    ret


print_hex_digit:
    push ax

    and al, 0x0F            ; Asegurar que solo sea un nibble
    cmp al, 9
    jle .is_digit

    ; Es A-F
    add al, 'A' - 10
    jmp .print

.is_digit:
    ; Es 0-9
    add al, '0'

.print:
    mov ah, 0x0E            ; Función BIOS: Teletype output
    mov bh, 0               ; Página de video
    mov bl, 0x07            ; Atributo (gris claro)
    int 0x10                ; Llamar interrupción BIOS

    pop ax
    ret

;*****************************************************************************
; Imprime valor hexadecimal (en dx).
;*****************************************************************************
print_hex_dword:
    push dx
    push ax

    ; Imprimir palabra alta
    mov ax, dx
    call print_hex_word

    ; Imprimir palabra baja
    pop ax
    call print_hex_word

    pop dx
    ret

;*****************************************************************************
; Imprime valor hexadecimal en memoria (en si).
;*****************************************************************************
print_memory_hex:
    push ax
    push cx
    push si

.loop:
    test cx, cx
    jz .done

    mov al, [si]
    call print_hex_byte

    ; Imprimir espacio
    mov al, ' '
    mov ah, 0x0E
    int 0x10

    inc si
    dec cx
    jmp .loop

.done:
    pop si
    pop cx
    pop ax
    ret

;*****************************************************************************
; Imprime salto de línea (10, 13).
;*****************************************************************************
print_newline:
    push ax

    mov al, 0x0D            ; Retorno de carro
    mov ah, 0x0E
    int 0x10

    mov al, 0x0A            ; Nueva línea
    mov ah, 0x0E
    int 0x10

    pop ax
    ret
