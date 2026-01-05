[BITS 16]
[ORG 0x7C00]

start:
    mov [boot_drive], dl  ; el disco de arranque.

    ; Inicializar serial: COM1
    call init_com1

    ; Activar A20 (+20 bits de direccionamiento)
    ; Posiblemente ya activa, pero por si acaso.
    in al, 0x92         ; Leer del puerto del controlador del sistema
    or al, 2            ; Activar el bit A20
    out 0x92, al        ; Escribir de vuelta

    ; Cargar GDT pre-paso a Modo Protegido.
    lgdt [gdt_ref]

    ; Solicitamos Modo Protegido
    mov eax, cr0
    or  eax, 1  ; Establecemos el PE (Protection Enable) bit
    mov cr0, eax

    ; Salto para forzar vaciado de caché de instrucciones.
    ; DEBE SER UN FAR JUMP, pero nasm dará error si usamos far.
    jmp dword .clear_instr_cache

.clear_instr_cache:
    ; Ponemos los registros apuntando a direcciones altas.
    mov ax, DATA_SEG  ; 0x10 (GDT)
    mov ds, ax    ; Cargar DS con descriptor de 4GB
    mov es, ax    ; Cargar ES con descriptor de 4GB
    mov fs, ax    ; Cargar FS con descriptor de 4GB
    mov gs, ax    ; Cargar GS con descriptor de 4GB
    mov ss, ax    ; Cargar SS con descriptor de 4GB

    ; BACK TO UNREAL
    mov eax, cr0
    and eax, 0xfffe
    mov cr0, eax

    ; Salto para forzar vaciado de caché de instrucciones.
    ; DEBE SER UN FAR JUMP, pero nasm dará error si usamos far.
    jmp 0x0000:unreal_mode

unreal_mode:
    ; Restaurar registros de segmento a valores de Modo Real.
    ; [CRÍTICO] Si no hacemos esto, van a pasar cosas "raras". Por ejemplo,
    ; no funcionarán bien las interrupciones.
    mov ax, 0x0000
    mov ss, ax

    mov si, msg_stage1_completed_ok
    call debug_print_string16
    ;*************************************************************************
    ; BEGIN: preparados para ir a stage2
    ; 1. LEER DEL DISCO el contenido de stage2.
    ; - sector 1:
    ; - 2 sectores.
    ; -> 0x8000
    ;*************************************************************************
    mov eax, 1            ; sector inicial.
    xor edx, edx          ; sector inicial (parte alta)
    ; Hemos aumentado el tamaño del stage2 para poder incorporar más cosas.
    ; Ahora son 4096 bytes / 8 sectores.
    mov cx, 8             ; total de sectores a leer.
    mov dl, [boot_drive]  ; la unidad de disco de donde leer.
    mov edi, 0x8000

    push dword 0
    pop es
    call read_sectors_lba
    ; Si error...
    jc error_lectura_disco

    ; Vamos a verificar que hemos leído stage2 correctamente:
    ; - Para eso usaremos nuestra firma inventada (AAAABBBBCCCC).
    ; - Debemos leer los tres últimos 12 bytes
    ;   desde la posición inicial donde hemos cargado los sectores.
    ;   Hemos cargado en 0x8000, a eso le sumamos 4084 (4096 - 12).
    mov esi, 0x8000
    ; Antes 1012, ahora 4084.
    add esi, 4084

    ; Verificar AAAA BBBB CCCC
    cmp dword [esi], 0x41414141      ; "AAAA"
    jne firma_mala_a

    cmp dword [esi+4], 0x42424242    ; "BBBB"
    jne firma_mala_b

    cmp dword [esi+8], 0x43434343    ; "CCCC"
    jne firma_mala_c

    ;*************************************************************************
    ; DESDE AQUÍ, pasamos a STAGE2
    ;*************************************************************************
    ; Volvemos a poner el valor de DL, por si acaso.
    mov dl, [boot_drive]  ; guardar el disco de arranque en DL antes de saltar.

    ; Saltamos a STAGE2.
    jmp 0x8000


error_lectura_disco:
    mov si, msg_disk_error
    call debug_print_string16

    hlt
    jmp $

firma_mala_a:
    mov si, msg_firma_mala_a
    call debug_print_string16

    hlt
    jmp $

firma_mala_b:
    mov si, msg_firma_mala_b
    call debug_print_string16

    hlt
    jmp $

firma_mala_c:
    mov si, msg_firma_mala_c
    call debug_print_string16

    hlt
    jmp $
;*****************************************************************************
; //END: fin de la lógica de stage1.
;*****************************************************************************
;*****************************************************************************
; BEGIN: inclusión de ficheros externos.
;*****************************************************************************
%include "globals.asm"
%include "serial.asm"
%include "disk.asm"
;*****************************************************************************
; //END: fin de la inclusión de ficheros externos.
;*****************************************************************************
;*****************************************************************************
; BEGIN: inicio de la lógica de la GDT.
;*****************************************************************************
; Una GDT básica preparada para entrar en Modo Protegido y salir de vuelta a (Ir)real.
;gdt:
    ; Null descriptor
;    dw 0x0000, 0x0000, 0x0000, 0x0000
    ; Code segment descriptor (base=0, limit=4GB, code segment, read/execute)
;    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF
    ; Data segment descriptor (base=0, limit=4GB, data segment, read/write)
;    dw 0xFFFF, 0x0000, 0x9200, 0x00CF

gdt:
    ; Null descriptor
    dd 0x00000000, 0x00000000
    ; Code segment: base=0, limit=0xFFFFF, 32-bit, readable
    dd 0x0000FFFF, 0x00CF9A00
    ; Data segment: base=0, limit=0xFFFFF, 32-bit, writable
    dd 0x0000FFFF, 0x00CF9200

gdt_ref:
    dw gdt_end - gdt - 1    ; Limit of GDT
    dd gdt                  ; Base address of GDT
gdt_end:

; Definiciones y algunas variables.
DATA_SEG equ 0x10
CODE_SEG equ 0x08
;*****************************************************************************
; //END: fin de la lógica de la GDT.
;*****************************************************************************
;*****************************************************************************
; BEGIN: inicio de datos.
;*****************************************************************************
msg_stage1_completed_ok:  db '[STAGE1] Completado OK!', 13, 10, 0
msg_disk_error:           db '[STAGE1] Error de disco.', 13, 10, 0
msg_firma_mala_a:         db '[STAGE1] AAAA => ERROR!', 13, 10, 0
msg_firma_mala_b:         db '[STAGE1] BBBB => ERROR!', 13, 10, 0
msg_firma_mala_c:         db '[STAGE1] CCCC => ERROR!', 13, 10, 0
;*****************************************************************************
; //END
;*****************************************************************************
times 510-($-$$) db 0
dw 0xAA55