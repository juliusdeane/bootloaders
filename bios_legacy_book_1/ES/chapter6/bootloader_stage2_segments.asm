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
    mov si, msg_kernel_begin_load
    call debug_print_string16

    mov eax, 9              ; sector inicial (final de stage2 en el disco).
    xor edx, edx            ; sector inicial (parte alta)
    mov cx, 29221           ; total de sectores a leer.
    ; mov dl, [boot_drive]  ; la unidad de disco de donde leer.
    mov edi, 0x1000000      ; ZONA ALTA DE MEMORIA (16 MB)
    ; Inicio:  0x01000000  (16 MB)
    ; Tamaño:  0x00E43E00  (~14.27 MB) (29221 x 512)
    ; Final:   0x01E43E00

    push dword 0
    pop es

    ; copia a memoria alta.
    call read_sectors_to_high_mem

    ; Si error...
    jc error_lectura_disco

    mov si, msg_kernel_loaded
    call debug_print_string16
    ;*************************************************************************
    ; //FIN: LEER EL (ENORME) KERNEL DE LINUX EN MEMORIA.
    ;*************************************************************************

    ;*************************************************************************
    ; LEER NUESTRO INITRD EN MEMORIA.
    ; - vamos a usar las siguientes direcciones y valores de referencia:
    ; - Destino: 0x800000
    ;*************************************************************************
    ; Ya no lo necesitamos, sabemos que funciona.
    ; mov si, msg_initrd_begin_load
    ; call debug_print_string16
    ; OFFSET: 0x00e45ba0 (14965664) =>
    mov eax, 14965664     ; Offset inicial de initrd en bytes.
    mov dl, [boot_drive]  ; la unidad de disco de donde leer.
    mov ecx, 1100000      ; Tamaño máximo (protección) => 1.100.000
    mov edi, 0x800000     ; a donde debe estar ubicado.

    push dword 0
    pop es

    mov si, msg_initrd_begin_load
    call debug_print_string16

    ; Leemos hasta la firma (12 bytes)
    call read_until_signature

    ; Si error...
    jc error_lectura_disco

    ; El total de bytes leídos de initrd.
    mov [initrd_bytes], eax

    ; INITRD cargado.
    mov si, msg_initrd_loaded
    call debug_print_string16
    ;*************************************************************************
    ; //FIN: LEER NUESTRO INITRD EN MEMORIA.
    ;*************************************************************************

;*****************************************************************************
; Seguimos el Linux Boot Protocol, usando 0x1000000 como staging
;*****************************************************************************
    ; Vamos a usar ESI para referenciar 0x1000000.
    ; - originalmente usábamos ESI, pero como vamos a añadir mucha info. de
    ;   diagnóstico y necesita SI, pasamos a usar EDI.
    ; mov esi, 0x1000000             ; kernel_base
    mov edi, 0x1000000             ; kernel_base

    ; Paso 1. Leer la firma HdrS (no lo hacemos).
    ; Paso 2.VAMOS A LEER setup_sects
    mov si, msg_setup_load
    call debug_print_string16

    movzx eax, byte [edi + 0x1F1]  ; setup_sects
    test eax, eax
    jnz .got_setup_sects
    ; Recuerda, si es 0, debe valer 4.
    mov eax, 4
.got_setup_sects:
    ; Si no era 0, usamos el valor de eax.
    ; Paso 3.Calculamos setup_size
    inc eax                ; (setup_sects + 1)
    shl eax, 9             ; *512
    mov [setup_size], eax

    ; Paso 4.copiamos el setup a 0x90000.
    mov esi, 0x1000000  ; De nuevo ESI refiere a kernel_base.
    mov edi, 0x90000
    mov ecx, [setup_size]
.copy_setup:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy_setup

    ; Verificar que el setup se copió bien
    mov esi, 0x90000
    cmp word [esi + 0x1FE], 0xAA55    ; Boot signature
    jne bad_setup
    cmp dword [esi + 0x202], 0x53726448  ; "HdrS"
    jne bad_setup

    ; setup correctamente cargado.
    mov si, msg_setup_ok
    call debug_print_string16

    ; Paso 5. El PAYLOAD (kernel comprimido)
    ; Informamos de que vamos a cargar el payload.
    mov si, msg_payload_load
    call debug_print_string16

    ; TRES nops que buscaremos con searchmem
    ; searchmem 0x909090 $pc
    nop
    nop
    nop

    mov esi, 0x1000000     ; kernel_base
    add esi, [setup_size]  ; Sumamos a 0x1000000 el tamaño del setup.
    mov edi, 0x100000      ; Ubicación destino del payload

    ; kernel: vmlinuz-6.8.0-86-generic
    ; Conocemos el tamaño exacto: 14961032
    ; 29221 * 512 = 14961152 (un poco más)
    ; mov ecx, (29221 * 512)
    mov ecx, 14961032      ; tamaño exacto
    sub ecx, [setup_size]  ; restamos el tamaño del setup.

.copy_payload:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy_payload

    ; Terminado, mostramos mensaje de aviso.
    mov si, msg_payload_ok
    call debug_print_string16

    ;*************************************************************************
    ; Kernel CMDLINE:
    ;*************************************************************************
    ; Ejemplo: cmdline en 0x20000
    mov si, msg_kernel_cmdline
    mov di, 0x20000
.copy_cmd:
    lodsb
    stosb
    test al, al
    jnz .copy_cmd

    ; Puntero cmdline en setup_header + 0x228
    mov dword [0x00090000 + 0x228], 0x00020000

    ; Imprimirá un mensaje de OK e inmediatamente añade "auto".
    ; No hemos terminado la cadena con 0:
    ; - sigue hasta leer msg_kernel_cmdline (y su nulo al final)
    mov si, msg_cmdline_ok
    call debug_print_string16
    ;*************************************************************************
    ; Initrd: lo hemos leído antes.
    ;*************************************************************************
    ;   ramdisk_image  -> offset 0x218 (0x800000)
    ;   ramdisk_size   -> offset 0x21C (bytes leídos: [initrd_bytes])
    ;*************************************************************************
    mov dword [0x00090000 + 0x218], 0x800000  ; ramdisk_image

    mov eax, [initrd_bytes]                   ; Nuestra variable intermedia a eas.
    mov dword [0x00090000 + 0x21C], eax       ; ramdisk_size

    ;*************************************************************************
    ; Tipo de bootloader.
    ;*************************************************************************
    mov byte [0x00090000 + 0x210], 0xff  ; Bootloader indefinido

    ; OK con el kernel.
    mov si, msg_kernel_ready
    call debug_print_string16

    ;*************************************************************************
    ; 7. Saltar al setup
    ;*************************************************************************

    ;*************************************************************************
    ; BEGIN: CUATRO nops seguidos para localizarlos visualmente y parar.
    ;*************************************************************************
    times 4 nop
    ;*************************************************************************
    ; //END: CUATRO nops seguidos para localizarlos visualmente y parar.
    ;*************************************************************************

    ; EL SALTO AL VACÍO... de transferir el control al kernel :)
    ; jmp 0x9020:0x0000

    ; Alternativa sin ljmp
    ; https://docs.kernel.org/arch/x86/boot.html
    ;/*
    ; * Note: in the case of the "old" kernel protocol, base_ptr must
    ; * be == 0x90000 at this point; see the previous sample code.
    ; */
    ;seg = base_ptr >> 4;

    ;cli();                        /* Enter with interrupts disabled! */

    ; /* Set up the real-mode kernel stack */
    ;_SS = seg;
    ;_SP = heap_end;

    ;_DS = _ES = _FS = _GS = seg;
    ;jmp_far(seg + 0x20, 0);       /* Run the kernel */
    cli

    mov ax, 0x9000
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0xffff

    ; El setup las volverá a activar.
    ; sti

    ;*************************************************************************
    ; BEGIN: CINCO nops seguidos para localizarlos visualmente y parar.
    ;*************************************************************************
    times 5 nop
    ;*************************************************************************
    ; //END: CINCO nops seguidos para localizarlos visualmente y parar.
    ;*************************************************************************

    ; equivalente a ljmp
    ; - toma IP de la pila (push ax, 0x9020)
    ; - toma CS de la pila (push 0x0000)
    mov ax, 0x9020
    push ax
    push word 0x0000
    retf
    ; jmp 0x9020:0x0000

    ; Si quieres aún más control, usa esto:
    ; mov ax, 0x9000
    ; mov cs, ax              ; ¡ERROR! CS no se puede mover directamente
    ; jmp 0x0200              ; salto relativo

;*****************************************************************************
; // END: código principal.
;*****************************************************************************
error_lectura_disco:
    mov si, msg_disk_error
    call debug_print_string16

    hlt
    jmp $

bad_setup:
    mov si, msg_bad_setup
    call debug_print_string16

    hlt
    jmp $

%include "globals.asm"
%include "serial.asm"
%include "disk_extended.asm"

;*****************************************************************************
; DATOS Y MENSAJES DE DEBUG:
;*****************************************************************************
msg_stage2_ok:          db '[STAGE2] Corriendo OK!', 13, 10, 0
msg_disk_error:         db '[STAGE2] Error de disco:', 13, 10, 0
msg_bad_setup:          db '[KERNEL] Error en el setup:', 13, 10, 0
msg_kernel_begin_load:  db '[KERNEL] Carga:', 13, 10, 0
msg_kernel_loaded:      db '[KERNEL] Cargado!', 13, 10, 0

msg_initrd_begin_load:  db '[INITRD] Cargando:', 13, 10, 0
msg_initrd_loaded:      db '[INITRD] Cargado!', 13, 10, 0

msg_setup_load:         db 13, 10, '[KERNEL] setup cargando:', 13, 10, 0
msg_setup_ok:           db '[KERNEL] setup correcto!', 13, 10, 0

msg_payload_load:       db 13, 10, '[KERNEL] payload cargando:', 13, 10, 0
msg_payload_ok:         db '[KERNEL] payload correcto!', 13, 10, 0

; Falta un CR/LF al combinar la cadena msg_cmdline_ok con msg_kernel_cmdline
msg_kernel_ready:       db 13, 10, 13, 10, '[KERNEL] TODO OK => jmp', 13, 10, 0

; VARIABLES PARA EL KERNEL BOOT PROTOCOL.
setup_size:          dd 0
initrd_bytes:        dd 0

; Esta cadena NO está terminada, porque la termina la siguiente.
msg_cmdline_ok:         db 13, 10, '[KERNEL] cmdline OK='

; msg_kernel_cmdline:  db "root=/dev/ram0 rw console=ttyS0", 0
msg_kernel_cmdline:  db "auto", 0
;*****************************************************************************
; PADDING + Signature:
; - para stage2 nos lo hemos inventado nosotros.
; - AAAA BBBB CCCC (12 bytes)
;*****************************************************************************
; 4096 - 12 bytes = 4084
; 4096 (8 sectores) + MBR (1 sector) = 9 sectores.
times 4084-($-$$) db 0x0
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
