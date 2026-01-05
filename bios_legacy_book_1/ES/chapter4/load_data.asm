load_data:
    ; PASO 1: Cargar desde disco usando INT 13h
    ; INT 13h necesita ES:BX en memoria convencional (<1MB)

    push es           ; Guardar ES (tiene límite 4GB)

    ; Configurar ES para el BIOS (sin tocar DS)
    xor ax, ax
    mov es, ax                ; ES = 0 (ahora límite 64KB normal)

    mov ah, 0x00              ; Función: reset
    mov dl, [boot_drive]

    mov si, msg_0
    call debug_print_string16

    int 0x13
    jc .disk_error            ; Si falla el reset

    mov bx, TEMP_READ_OFFSET  ; Buffer temporal
    ; Leer disco CHS.
    mov ah, 0x02
    mov ch, 0
    mov dh, 0
    mov cl, 3                      ; Sector de inicio.
    mov al, TOTAL_SECTORS_TO_READ  ; 10 sectores
    mov dl, [boot_drive]           ; Nuestro disco.

    int 0x13                       ; Lee a ES:BX = 0x0000:0x7E00

    pop es                         ; Restaurar ES (límite 4GB otra vez)

    ; mov si, msg_1
    ; call debug_print_string16

    ; PASO 2: Copiar a memoria alta (>1MB)
    ; Ahora usamos DS (que nunca se tocó y tiene límite 4GB)

    mov esi, TEMP_READ_OFFSET    ; Origen (memoria baja)
    mov edi, KERNEL_LOAD_ADDR    ; Destino (1MB+) - REQUIERE límite extendido
    mov ecx, TOTAL_SECTORS_SIZE  ; 10 sectores * 512 bytes

    ; mov si, msg_2
    ; call debug_print_string16

    ; movsb usa DS:ESI y ES:EDI por defecto
    ; Como DS y ES tienen límite 4GB, funciona
    rep movsb

    ; mov si, msg_3
    ; call debug_print_string16

    ret

.disk_error:
    ; En error, no lo habíamos restaurado.
    pop es

    mov si, msg_disk_error
    call debug_print_string16

    ret
