;*****************************************************************************
; DEBUG en HEXADECIMAL utilizando la consola serial.
; - contenido de EBX en texto en COM1.
;*****************************************************************************
print_hex_serial:
    pusha

    mov ecx, 8               ; 8 dígitos hex (32 bits)

.loop:
    rol ebx, 4               ; Rotar 4 bits a la izquierda
    mov al, bl               ; Copiar byte bajo
    and al, 0x0F             ; Quedarse con 4 bits bajos

    ; Convertir a ASCII
    cmp al, 9
    jbe .digit
    add al, 7                ; A-F
.digit:
    add al, '0'              ; 0-9

    mov dx, COM1
    out dx, al

    dec ecx
    jnz .loop

    ; Imprimir nueva línea
    mov al, 13
    out dx, al
    mov al, 10
    out dx, al

    popa
    ret

;*****************************************************************************
; DEBUG en HEXADECIMAL utilizando la salida estándar.
; - contenido de EBX en texto en pantalla.
;*****************************************************************************
print_hex_screen:
    pusha
    mov edi, 0xB8000         ; Video memoria (ajusta según tu posición)
    add edi, (80*2*10 + 2*0) ; Fila 10, columna 0 (ejemplo)

    mov ecx, 8               ; 8 dígitos

.loop:
    rol ebx, 4
    mov al, bl
    and al, 0x0F

    cmp al, 9
    jbe .digit
    add al, 7
.digit:
    add al, '0'

    mov ah, 0x0F             ; Blanco sobre negro
    mov [edi], ax            ; Escribir en video memoria
    add edi, 2               ; Siguiente posición

    dec ecx
    jnz .loop

    popa
    ret

;*****************************************************************************
; DEBUG utilizando la consola serial - NG. Vigilando que DS tenga el valor
; correcto para poder direccionar los mensajes.
; - texto en COM1.
;*****************************************************************************
debug_print_string:
    ; Imprimimos el contenido de la cadena de texto en SI, a través del COM1.

    ; pusha no va a proteher DS, por lo que lo hacemos a mano.
    push ds

    ; Protegemos los registros en la pila.
    pusha

    ; Apuntamos DS al valor que tenga CS (code segment).
    mov cx, cs
    mov ds, cx

.debug_print_string_loop:
    ; 1. Carga el byte de la memoria apuntada por DS:SI en AL.
    ;    (Reemplazo directo de la funcionalidad de lodsb, excepto por el incremento)
    mov al, [si]

    ; 2. Comprueba si el byte cargado es cero (terminador de cadena)
    test al, al
    jz .debug_print_string_done

    ; 3. Incrementa manualmente el puntero de la cadena (el equivalente al lodsb)
    inc si

    ; 4. Envía el byte al puerto COM1
    mov dx, COM1
    out dx, al

    jmp .debug_print_string_loop

.debug_print_string_done:
    ; Rastauramos.
    popa
    pop ds
    ret
