;*****************************************************************************
; Modo (ir)real, 16 bits, offset 0x8000
; - la posición donde cargamos estos sectores.
;*****************************************************************************
[BITS 16]
[ORG 0x8000]

;*****************************************************************************
; INICIO del código
;*****************************************************************************
stage2_start:
    ; Acabo de aterrizar desde el jmp, vuelvo a guardar el valor
    ; y así, de nuevo, tenemos el boot_drive correcto.
    mov [boot_drive], dl

    mov si, msg_stage2_ok
    call debug_print_string16

    ; CRÍTICO: no olvidemos configurar el STACK:
    ; - preparamos la PILA.
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0x7C00      ; Stack crece hacia abajo desde 0x7C00

    ;*************************************************************************
    ; LEER EL (ENORME) KERNEL DE LINUX EN MEMORIA.
    ;*************************************************************************
    mov eax, 3            ; sector inicial (final de stage2 en el disco).
    xor edx, edx          ; sector inicial (parte alta)
    mov cx, 29221         ; total de sectores a leer.
    ; mov dl, [boot_drive]  ; la unidad de disco de donde leer.
    mov edi, 0x1000000    ; ZONA ALTA DE MEMORIA (16 MB)
    ; Inicio:  0x01000000  (16 MB)
    ; Tamaño:  0x00E43E00  (~14.27 MB) (29221 x 512)
    ; Final:   0x01E43E00

    push dword 0
    pop es

    ;*************************************************************************
    ; TODAS estas funciones tienen el problema de acceder con int 13h por
    ; encima del 1 MB. No pueden.
    ;*************************************************************************
    ; La original: read_sectors_lba
    ;
    ; Esta versión modificada imprime + por cada sector leído.
    ; - el problema es que es LENTA, hace unas 30.000 llamadas × 10ms = 300 segundos
    ; - lee UN sector en cada llamada.
    ; call read_sectors_lba_status

    ; Esta versión rápida intenta leer 127 sectores de una vez, lo que reduce el total de llamadas
    ; a aproximadamente 230: 230 llamadas × 10ms = 2,3 segundos  ⚡
    ; call read_sectors_lba_fast
    ;*************************************************************************
    ; // END TODAS estas funciones tienen el ...
    ;*************************************************************************
    ; Esta nueva versión usa un buffer intermedio en memoria baja y luego
    ; copia a memoria alta.
    call read_sectors_to_high_mem

    ; Si error...
    jc error_lectura_disco

    mov si, msg_kernel_loaded
    call debug_print_string16

    mov si, msg_kernel_jmp
    call debug_print_string16

    ; WAIT_KEY:
    mov ah, 0x00
    int 0x16

    ; Saltamos a 0x1000000 + 0x200
    ; - punto de entrada justo tras el 0xaa55.
    jmp 0x1000200

error_lectura_disco:
    mov si, msg_disk_error
    call debug_print_string16

    hlt
    jmp $

%include "globals.asm"
%include "serial.asm"
%include "disk_extended.asm"

msg_stage2_ok:      db '[STAGE2] Corriendo OK!', 13, 10, 0
msg_disk_error:     db '[STAGE2] Error de disco.', 13, 10, 0
msg_kernel_loaded:  db '[KERNEL] Cargado!', 13, 10, 0
msg_kernel_jmp:     db '[KERNEL] Pulsa una tecla para saltar a 0x1000200', 13, 10, 0

;*****************************************************************************
; PADDING + Signature:
; - para stage2 nos lo hemos inventado nosotros.
; - AAAA BBBB CCCC (12 bytes)
;*****************************************************************************
; 1024 - 12 bytes = 500
; 1024 (2 sectores) + MBR (1 sector) = 3 sectores.
times 1012-($-$$) db 0x0
db 0x41 ; A
db 0x41 ; A
db 0x41 ; A
db 0x41 ; A
db 0x42 ; B
db 0x42 ; B
db 0x42 ; B
db 0x42 ; B
db 0x43 ; C
db 0x43 ; C
db 0x43 ; C
db 0x43 ; C
