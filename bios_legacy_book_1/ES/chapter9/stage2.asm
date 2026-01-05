[BITS 16]
[ORG 0x8000]


stage2_start:
    mov [boot_drive], dl

    ; Seguimos en Modo Real: DETECTAMOS MEMORIA DISPONIBLE
    call detect_memory

    ; Detectamos modos de video
    ; Ponemos el modo de video al estilo Ninja :)
    mov ax, VIDEO_MODE
    int 0x10

    ; Preparo la pila (vamos a usar call)
    ; - por ahora seguimos en 16 bits.
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack crece hacia abajo desde 0x7C00

    ; [MODO PROTEGIDO] Paso 0: desactivar IRQs.
    ; - cli
    cli

    ; [MODO PROTEGIDO] Paso 1.
    ; - Cargamos la GDT.
    lgdt [gdt_ref]

    ; [MODO PROTEGIDO] Paso 2.
    ; - Activar A20 (+20 bits de direccionamiento)
    in al, 0x92         ; Leer del puerto del controlador del sistema
    or al, 2            ; Activar el bit A20
    out 0x92, al        ; Escribir de vuelta

    ; [MODO PROTEGIDO] Paso 3.
    ; - Bit PE=1
    mov eax, cr0
    or  eax, 1  ; Establecemos el PE (Protection Enable) bit
    mov cr0, eax

    ; [MODO PROTEGIDO] Paso 4.
    ; Salto para forzar vaciado de caché de instrucciones.
    ; DEBE SER UN FAR JUMP, pero nasm dará error si usamos far.
    jmp dword CODE_SEG:clear_instr_cache32

[BITS 32]
; ESTAMOS EN 32 BITS DESDE AQUÍ.
clear_instr_cache32:
    ; Ponemos los registros apuntando a direcciones altas.
    mov ax, DATA_SEG  ; 0x10 (GDT)
    mov ds, ax        ; Cargar DS con descriptor de 4GB
    mov es, ax        ; Cargar ES con descriptor de 4GB
    mov fs, ax        ; Cargar FS con descriptor de 4GB
    mov gs, ax        ; Cargar GS con descriptor de 4GB
    mov ss, ax        ; Cargar SS con descriptor de 4GB
    mov sp, 0x7C00    ; PILA crece hacia abajo, de 0x7c00 a 0x0000.

    ; Probemos que la GDT funciona:
    ; - verificar que podemos escribir en memoria
    ; Test de escritura
    mov dword [0x8000], 0x12345678
    mov eax, [0x8000]
    cmp eax, 0x12345678
    jne pm_bad_gdt

    ; Leo el contenido de STAGE3 en memoria.
    mov eax, STAGE3_START_SECTOR    ; Sector inicial (LBA)
    ; Número de sectores a leer: STAGE3_SIZE_SECTORS + margen
    mov ecx, STAGE3_SIZE_SECTORS + 16
    mov edi, STAGE3_ADDRESS         ; Dirección destino (puede ser > 1 MB)
    xor edx, edx
    mov dl, [boot_drive]            ; Asegurar EDX limpio (precaución)

    call read_sectors_pm

    ; Si error...
    jc error_stage3_read

    mov [stage3_read_sectors], eax
    shl eax, 9  ; x 512 = bytes
    mov [stage3_read_bytes], eax
    ; En versiones posteriores podemos incluir verificaciones de que hemos
    ; leído el contenido esperado.

    ; Leo el contenido de KERNEL en memoria.
    mov eax, KERNEL_C_START_SECTOR    ; Sector inicial (LBA)
    ; Número de sectores a leer: STAGE3_SIZE_SECTORS + margen
    mov ecx, KERNEL_C_SIZE_SECTORS + 16
    mov edi, KERNEL_ADDRESS         ; Dirección destino (puede ser > 1 MB)
    xor edx, edx
    mov dl, [boot_drive]            ; Asegurar EDX limpio (precaución)

    call read_sectors_pm

    ; Si error...
    jc error_kernel_c_read

    ; Si ha sido correcto:
    ; - stage3 en 0x100000 preparado
    ; - kernel en 0x300000 preparado
    jmp STAGE3_ADDRESS
;*****************************************************************************
; // END: código principal.
;*****************************************************************************

;*****************************************************************************
; Código ERRORES
;*****************************************************************************
pm_bad_gdt:
    mov esi, msg_pm_bad_gdt
    call puts_serial
    hlt
    jmp $
    dw 'ERR1'

error_stage3_read:
    mov esi, msg_stage3_read_error
    call puts_serial

    hlt
    jmp $
    dw 'ERR2'

error_kernel_c_read:
    mov esi, msg_kernel_c_read_error
    call puts_serial

    hlt
    jmp $
    dw 'ERR3'
;*****************************************************************************
; //END: código ERRORES
;*****************************************************************************

%include "globals.asm"
%include "structure.asm"
%include "gdt32.asm"
%include "serial32.asm"
%include "disk32.asm"
%include "detect_memory.asm"

;*****************************************************************************
; DATOS Y MENSAJES DE DEBUG:
;*****************************************************************************
CR_LF:                    db 13, 10, 0
SEPARATOR:
  times 79 db '='
  db 13, 10, 0

stage3_read_sectors:            dd 0
stage3_read_bytes:              dd 0

msg_pm_bad_gdt:                 db 13, 10, '[STAGE2] GDT Incorrecta :(', 13, 10, 0
msg_pm_ok:                      db 13, 10, '[STAGE2] Modo protegido OK!', 13, 10, 0
msg_stage3_read_error:          db 13, 10, '[STAGE2] ERROR leyendo stage3 :(', 13, 10, 0
msg_kernel_c_read_error:        db 13, 10, '[STAGE2] ERROR leyendo kernel :(', 13, 10, 0
;*****************************************************************************
; PADDING + Signature:
; - para stage2 nos lo hemos inventado nosotros.
; - AAAA BBBB CCCC (12 bytes)
;*****************************************************************************
; 8192 - 12 bytes = 8180
; 8192 (16 sectores) + MBR (1 sector) = 17 sectores.
times 8180-($-$$) db 0x0
; Simplificamos nuestra firma.
times 4 db 0x41
times 4 db 0x42
times 4 db 0x43
