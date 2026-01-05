COM1   equ 0x03f8

;*****************************************************************************
; Inicializar el COM1.
;*****************************************************************************
init_com1:
    pusha

    ; Deshabilitar interrupciones
    mov     dx, COM1 + 1  ; FCR - FIFO Control Register
    mov     al, 00h       ; Deshabilitar FIFO
    out     dx, al

    ; Establecer el divisor (para 9600 baudios con clock 1.8432 MHz)
    mov     dx, COM1 + 3   ; LCR - Line Control Register
    mov     al, 10000000b  ; Establecer DLAB=1 (acceso al divisor)
    out     dx, al

    mov     dx, COM1 + 0    ; LSB del divisor (115200 / 9600 = 12 = 0Ch)
    mov     al, 0Ch
    out     dx, al

    mov     dx, COM1 + 1     ; MSB del divisor
    mov     al, 00h
    out     dx, al

    ; Configurar el formato de línea (8N1 - 8 bits, Sin paridad, 1 bit de parada)
    mov     dx, COM1 + 3   ; LCR - Line Control Register
    mov     al, 00000011b  ; DLAB=0, 8 bits de datos, sin paridad, 1 bit de parada
    out     dx, al

    popa
    ret

;*****************************************************************************
; DEBUG utilizando la consola serial.
; - texto en COM1.
;*****************************************************************************
debug_print_string16:
    ; Imprimimos el contenido de la cadena de texto en si, a través del COM1.
    ; Protegemos los registros en la pila.
    pusha

.debug_print_string16_loop:
    lodsb
    test al, al
    jz .debug_print_string16_done

    mov dx, COM1
    out dx, al
    jmp .debug_print_string16_loop

.debug_print_string16_done:
    popa

    ret
