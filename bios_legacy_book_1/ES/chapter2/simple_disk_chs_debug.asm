[BITS 16]                  ; Modo real, 16bits
[ORG 0x7C00]               ; MBR en 0x7C00.

start:
    ; IMPORTANTE: por pura precaución vamos a preparar el contexto del bootloader.
    ; DESACTIVAMOS LAS INTERRUPCIONES TEMPORALMENTE:
    ; - evitamos que el procesador haga cambios antes de dejar el entorno  preparado.
    cli

    ; [!!!] GUARDAMOS EL IDENTIFICADOR DEL DISCO DESDE DONDE ARRANCAMOS.
    mov [boot_drive], dl

    ; Ponemos ax=0 y movemos a los registros de segmento este valor:
    ; Clear and suspend interruptions
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; Vamos a preparar la pila (STACK) para ubicarla en una zona segura.
    mov ax, 0x9000
    mov ss, ax      ; Segmento de pila
    ; Ubicaremos justo en el límite superior.
    mov sp, 0xEFFF  ; Puntero de pila (crece hacia 0x7BFE, 0x7BFC...)
    ; Pila en: 0x9000:0xEFFF => 0x9EFFF

    ; Restauremos las interrupciones.
    sti

    mov si, mensaje_inicio
    ; IMPORTANTE: en esta función estamos protegiendo los registros,
    ; por lo que mensaje_inicio seguirá en si al salir de ella !
    call debug_print_string16
    call print_string
    call wait_key

    ; ************************************************************************
    ; CHS: LECTURA DEL SECTOR AQUÍ:
    ; ************************************************************************
    mov bx, 0x8000       ; Destino en memoria del contenido sector leído.
    mov ah, 0x02         ; Función 2: leer sectores
    mov al, 1            ; Número de sectores a leer (1).
    mov ch, 0            ; - cilindro = 0 (C)
    mov dh, 0            ; - cabeza = 0 (H)
    ; Inicialmente habíamos cometido un error al asignar el sector 1 a cl
    ; - el sector 1 es NUESTRO PROPIO BOOTLOADER !
    mov cl, 2            ; - sector = 2 (bits 0–5) (S)

    ; Si leemos del primer disco duro, dl debería ser 0x80.
    ; mov dl, 0x80         ; disco = primer disco duro (0x80)

    ; Pero vamos a leer desde NUESTRO PROPIO DISCO DE ARRANQUE !
    mov dl, [boot_drive]
    int 0x13
    ; Verificamos que no hemos tenido un errr.
    jc .error_disco_chs   ; si CF=1, error

    mov si, mensaje_ok
    ; IMPORTANTE: en esta función estamos protegiendo los registros,
    ; por lo que mensaje_ok seguirá en si al salir de ella !
    call debug_print_string16
    call print_string

    ; Si no ha habido error, vamos a imprimir las letras A!
    mov si, 0x8000
    call print_string
    ; ************************************************************************
    ; LECTURA DEL SECTOR CON CHS AQUÍ:
    ; ************************************************************************

    hlt
    jmp $

.error_disco_chs:
    mov si, mensaje_error
    ; IMPORTANTE: en esta función estamos protegiendo los registros,
    ; por lo que mensaje_error seguirá en si al salir de ella !
    call debug_print_string16
    call print_string

    hlt
    jmp $

; Recuerda: funciones de texto movidas aquí. Posteriormente añadiremos las de disco.
%include "bootloader_tools.asm"

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

boot_drive         db 0

mensaje_inicio     db '[!] Vamos a leer 1 sector (512 bytes) desde el disco.'
                   db ' Si todo va bien pondremos 512 Aes en pantalla.', 13, 10, 13, 10
                   db 'Pulsa una tecla para hacerlo:', 13, 10, 13, 10, 0

mensaje_ok         db '[OK] Hemos cargado el sector en 0x8000 :)', 13, 10, 0
mensaje_error      db '[ERROR] Error leyendo el disco :(', 13, 10, 0

times 510-($-$$) db 0x90   ; Pad con nop x 510 - tamaño del código.
dw 0xAA55
