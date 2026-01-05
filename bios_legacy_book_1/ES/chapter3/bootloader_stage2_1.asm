;*****************************************************************************
; Modo real, 16 bits, offset 0x8000
; - la posición donde cargamos estos sectores.
;*****************************************************************************
[BITS 16]
[ORG 0x8000]

;*****************************************************************************
; INICIO del código
;*****************************************************************************
stage2_start:
    call clear_screen

    mov si, mensaje_data
    call print_string16

    hlt
    jmp $
;*****************************************************************************
; //FIN del código
;*****************************************************************************

;*****************************************************************************
; INICIO de las funciones (las moveremos a otro archivo)
;*****************************************************************************
; Imprimir texto en pantalla.
print_string16:
    pusha
    mov ah, 0x0e        ; Teletype output
.loop:
    lodsb               ; Load byte from SI into AL
    cmp al, 0           ; Check for null terminator
    je .done
    int 0x10            ; Print character
    jmp .loop
.done:
    popa
    ret

; Imprimir texto en COM1.
debug_print_string16:
    ; Imprimimos el contenido de la cadena de texto en si, a través del COM1.
    ; Protegemos los registros en la pila.
    pusha

.debug_print_string16_loop:
    lodsb
    test al, al
    jz .debug_print_string16_done

    mov dx, 0x3F8
    out dx, al
    jmp .debug_print_string16_loop

.debug_print_string16_done:
    popa
    ret

; Limpiar pantalla.
clear_screen:
    pusha

    mov ah, 0x00        ; Set video mode
    mov al, 0x03        ; 80x25 text mode
    int 0x10            ; Video interrupt

    popa
    ret

; Espera pulsación de una tecla.
wait_key:
    pusha

    mov ah, 0x00
    int 0x16

    popa
    ret
;*****************************************************************************
; //FIN de las funciones.
;*****************************************************************************

;*****************************************************************************
; INICIO Datos
;*****************************************************************************
msg_stage2_cargado db '[STAGE2] Cargado correctamente.', 13, 10, 0

mensaje_data:
    incbin "mensaje.txt"
mensaje_stop db 0

;*****************************************************************************
; //FIN Datos
;*****************************************************************************
;*****************************************************************************
; Signature:
; - para stage2 nos lo hemos inventado nosotros.
; - AAAA BBBB CCCC (12 bytes)
;*****************************************************************************
db 0x41 ; A
db 0x41 ; A
db 0x41 ; A
db 0x41 ; A
db 0x42 ; A
db 0x42 ; A
db 0x42 ; A
db 0x42 ; A
db 0x43 ; C
db 0x43 ; C
db 0x43 ; C
db 0x43 ; C
