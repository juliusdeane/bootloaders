;*****************************************************************************
; Modo real, 16 bits, offset 0x7c00
;*****************************************************************************
[BITS 16]
[ORG 0x7C00]

;*****************************************************************************
; INICIO del código
;*****************************************************************************
start:
    cli

    ; Unidad de arranque.
    mov [boot_drive], dl

    ; Preparamos nuestro entorno.
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ax, 0x07F0
    mov ss, ax      ; Segmento de pila
    mov sp, 0xFFFE  ; Puntero de pila (crece hacia 0x7BFE, 0x7BFC...)

    sti

    ; PASO1: leemos los sectores del stage2.
    mov si, DAP           ; DS:SI apunta al DAP
    mov ah, 0x42          ; Lectura extendida
    ; Nuestro disco de arranque.
    mov dl, [boot_drive]
    int 0x13

    ; Verificamos que no hemos tenido un error.
    jc .error_disco   ; si CF=1, error

    ; SALTAMOS directamente a donde hemos cargado los sectores.
    ; Esperemos que sea código ejecutable :-?
    jmp 0x8000

.error_disco:
    mov si, mensaje_error
    call debug_print_string16

    hlt
    jmp $
;*****************************************************************************
; //FIN del código
;*****************************************************************************

;*****************************************************************************
; INICIO de las funciones
;*****************************************************************************
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
;*****************************************************************************
; //FIN de las funciones.
;*****************************************************************************

;*****************************************************************************
; INICIO Datos
;*****************************************************************************
; Nuestro disco de arranque
boot_drive db 0

; Error de lectura de disco
mensaje_error      db '[ERROR] Error leyendo el disco :(', 13, 10, 0

; DAP (Disk Address Packet)
DAP:
    db 0x10
    db 0
    ; Número de sectores a leer
    ; -> el tamaño de nuestra etapa2/stage2.
    dw 1

    ; Offset posición de memoria segura.
    dw 0x8000

    dw 0
    ; Empezamos en el LBA 1 (segundo sector).
    dq 1
;*****************************************************************************
; //FIN Datos
;*****************************************************************************
;*****************************************************************************
; PADDING + Signature
;*****************************************************************************
times 510-($-$$) db 0x90
dw 0xAA55
