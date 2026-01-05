[BITS 16]
[ORG 0x8000]


stage2_start:
    mov [boot_drive], dl

    ; Preparamos la PILA.
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0x7C00

    ; IMPORTANTE: no tocamos DS, ni ES. Los usaremos.
    ; stage2_optionb: 16 sectores.
    mov eax, KERNEL_INITIAL_SECTOR  ; sector inicial (final de stage2 en el disco).
    xor edx, edx  ; sector inicial (parte alta)
    mov cx, KERNEL_LOAD_SECTORS       ; total de sectores a leer.
    mov edi, KERNEL_LOAD_ADDRESS      ; ZONA ALTA DE MEMORIA (16 MB)

    ; ES=0
    push dword 0
    pop es

    ; copia a memoria alta.
    ; call read_sectors_to_high_mem
    ; Devuelve en EAX el total de bytes leídos.
    call read_sectors_to_high_mem_ng

    ; Si error...
    jc error_lectura_disco

    ; Vamos a usar ESI para referenciar 0x1000000.
    mov edi, KERNEL_LOAD_ADDRESS  ; kernel_base (staging)

    ;*************************************************************************
    ; VERIFICACIONES DE SALUD: que la versión sea la mínima aceptable.
    ; - verificar boot protocol version en staging.
    ;*************************************************************************
    mov ax, [edi + 0x206]  ; boot protocol version
    cmp ax, 0x0200         ; Necesitamos al menos 2.00
    jb bad_protocol

    ;*************************************************************************
    ; LEER NUESTRO INITRD EN MEMORIA.
    ; - vamos a usar las siguientes direcciones y valores de referencia:
    ; - Destino: 0x800000
    ;*************************************************************************
    ; stage2_optionb: 16 sectores.
    mov eax, INITRD_DISK_START_OFFSET  ; offset inicial de initrd en bytes (16 sectores).
    mov dl, [boot_drive]               ; la unidad de disco de donde leer.
    mov ecx, INITRD_MAX_LENGTH         ; Tamaño máximo (protección) => 1.100.000

    mov edi, INITRD_LOAD_ADDRESS
    mov [begin_initrd], edi

    ; ES=0
    push dword 0
    pop es

    ; Leemos hasta la firma (12 bytes)
    call read_until_signature

    ; Si error...
    jc error_lectura_disco

    ; El total de bytes leídos de initrd.
    mov [initrd_bytes], eax
    add ecx, edi
    mov [end_initrd], ecx

    ;*************************************************************************
    ; LINUX BOOT PROTOCOL:
    ; Seguimos el Linux Boot Protocol, usando 0x1000000 como staging
    ;
    ; PASO 0. Vamos a leer setup_sects
    ;*************************************************************************
    ; Volvemos a apuntar bien EDI.
    mov edi, KERNEL_LOAD_ADDRESS   ; kernel_base
    movzx eax, byte [edi + 0x1F1]  ; setup_sects
    test eax, eax
    jnz kernel_got_setup_sects

    ; Recuerda, si es 0, debe valer 4.
    ; si no es 0, no ejecuta la siguiente instrucción.
    mov eax, 4
kernel_got_setup_sects:
    ; Si no era 0, usamos el valor de eax.
    ; SETUP SIZE FINAL:
    inc eax                ; (setup_sects + 1)
    shl eax, 9             ; *512
    mov [setup_size], eax  ; aquí tenemos setup size.

    ;*************************************************************************
    ; PASO 1: Copiar el SETUP del kernel a 0x90000
    ;*************************************************************************
    mov esi, KERNEL_LOAD_ADDRESS   ; De nuevo ESI refiere a kernel_base.
    mov edi, KERNEL_SETUP_ADDRESS  ; Destino: donde Linux espera el setup.
    mov ecx, [setup_size]          ; ECX = 0x5000 bytes (20480)
.copy_setup:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy_setup

    ; Verificar que el setup se copió bien
    mov esi, KERNEL_LOAD_ADDRESS
    cmp word [esi + 0x1fe], MBR_SIG           ; Boot signature
    jne bad_setup
    cmp dword [esi + 0x202], KERNEL_HDRS_SIG  ; "HdrS"
    jne bad_setup
    ;*************************************************************************
    ; PASO 2: Copiar el PAYLOAD del kernel a 0x90000
    ;*************************************************************************
    mov esi, KERNEL_SETUP_ADDRESS
    mov eax, [esi + 0x1f4]  ; syssize = 0xE3F20 (desde el setup ya copiado)
    ; Multiplicado x 16:
    shl eax, 4                 ; ×16 = 0xE3F200 bytes = 14.958.592 bytes
    mov [header_syssize], eax  ; Lo guardo en una variable por ahora.

    ; Reemplazamos en ESI y cargamos el kernel_base (staging).
    mov esi, KERNEL_LOAD_ADDRESS     ; kernel_base staging origen.
    add esi, [setup_size]            ; Sumamos a 0x1000000 el tamaño del setup (por ejemplo, 5000).
    mov [st_payload_start], esi      ; Almaceno en mi variable: (staging) payload_start.

    mov edi, KERNEL_PAYLOAD_ADDRESS  ; Ubicación destino del setup.
    add edi, [setup_size]
    mov [ru_payload_start], edi      ; Almaceno en mi variable: (run) payload_start.

    ; ESI=origen (payload_start)
    ; EDI=destino (KERNEL_PAYLOAD_ADDRESS)
    mov esi, [st_payload_start]
    mov edi, KERNEL_PAYLOAD_ADDRESS
    mov eax, [header_syssize]  ; Recupero el tamaño.
    mov ecx, eax               ; ECX = tamaño en bytes del kernel
payload_copy_loop:
    mov al, [esi]            ; Leer 1 byte desde origen
    mov [edi], al            ; Escribir 1 byte a destino
    inc esi                  ; Avanzar origen
    inc edi                  ; Avanzar destino
    dec ecx                  ; Decrementar contador
    jnz payload_copy_loop    ; Continuar si ECX != 0

    ;*************************************************************************
    ; PASO 3: Kernel CMDLINE:
    ;*************************************************************************
    mov esi, msg_kernel_cmdline
    mov edi, KERNEL_CMDLINE_ADDRESS
    mov ecx, KERNEL_CMDLINE_SIZE  ; tamaño de msg_kernel_cmdline
cmdline_copy_loop:
    mov al, [esi]            ; Leer 1 byte desde origen
    mov [edi], al            ; Escribir 1 byte a destino
    inc esi                  ; Avanzar origen
    inc edi                  ; Avanzar destino
    dec ecx                  ; Decrementar contador
    jnz cmdline_copy_loop    ; Continuar si ECX != 0

    ; KERNEL_SETUP_CMDLINE_PTR = KERNEL_SETUP_ADDRESS + 0x228
    mov esi, KERNEL_SETUP_ADDRESS
    add esi, 0x228
    mov [esi], dword KERNEL_CMDLINE_ADDRESS

    ;*************************************************************************
    ; PASO 4: Ubicar Initrd: lo hemos leído antes.
    ;*************************************************************************
    mov eax, INITRD_LOAD_ADDRESS  ; EAX = valor a escribir => ramdisk_image
    mov edi, KERNEL_INITRD_PTR    ; EDI = dirección física destino
    mov [edi], eax                ; Escribir EAX en [EDI]

    mov eax, [initrd_bytes]       ; EAX = valor a escribir
    mov edi, KERNEL_INITRD_BYTES  ; EDI = dirección física destino
    mov [edi], eax                ; Escribir EAX en [EDI]

    ;*************************************************************************
    ; PASO 5: Tipo de bootloader.
    ;*************************************************************************
    mov eax, KERNEL_UNKNOWN_BOOTLOADER  ; Bootloader indefinido
    mov edi, KERNEL_BOOTLOADER_TYPE     ; EDI = dirección física destino
    mov [edi], eax                      ; Escribir EAX en [EDI]

    ;*************************************************************************
    ; PASO 6: Configurar loadflags
    ;*************************************************************************
    mov al, KERNEL_SET_LOADFLAGS  ; LOADED_HIGH (0x01) | CAN_USE_HEAP (0x80)
    mov edi, KERNEL_LOADFLAGS     ; Dirección destino
    mov [edi], al                 ; Escribir 1 byte

    ;*************************************************************************
    ; PASO 7: heap end ptr:
    ;*************************************************************************
    mov eax, KERNEL_SET_HEAP_END
    mov edi, KERNEL_HEAP_END_PTR
    mov [edi], eax  ; Heap termina en 0x9DE00

    ;*************************************************************************
    ; PASO 8: Saltar al setup
    ;*************************************************************************

    ; Detenemos las IRQ.
    cli

    ; Preparamos correctamente los segmentos.
    mov ax, 0x9000
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0xffff

    ; Equivalente a ljmp;
    ; - toma IP de la pila (push ax, 0x9020)
    ; - toma CS de la pila (push 0x0000)
    mov ax, 0x9020
    push ax
    push word 0x0000
    retf
;*****************************************************************************
; // END: código principal.
;*****************************************************************************
error_lectura_disco:
    mov si, msg_disk_error
    call debug_print_string

    hlt
    jmp $

bad_setup:
    mov si, msg_bad_setup
    call debug_print_string

    hlt
    jmp $

bad_protocol:
    mov si, msg_bad_setup
    call debug_print_string

    hlt
    jmp $

separator:
    push si

    mov si, SEPARATOR
    call debug_print_string

    pop si
    ret

%include "globals.asm"
%include "serial.asm"
%include "stage2_debug_ng.asm"
%include "disk_extended.asm"
;%include "kernel_extra_debug.asm"

;*****************************************************************************
; DATOS Y MENSAJES DE DEBUG:
;*****************************************************************************
CR_LF:                    db 13, 10, 0
SEPARATOR:
  times 79 db '='
  db 13, 10, 0
msg_disk_error:           db '[STAGE2] Error de disco:', 13, 10, 0
msg_bad_setup:            db '[STAGE2] [KERNEL] Mala confiuración:', 13, 10, 0

; Vamos a reducir el debug al mínimo.
;msg_stage2_ok:            db '[STAGE2] Corriendo OK!', 13, 10, 0
;msg_total_bytes_read:     db '[STAGE2] [DISK] Total bytes:', 13, 10, 0

; %include "kernel_header_msgs.asm"

; VARIABLES PARA EL KERNEL BOOT PROTOCOL.
setup_size:                 dd 0
st_payload_start:           dd 0
ru_payload_start:           dd 0
header_syssize:             dd 0
initrd_bytes:               dd 0
begin_initrd:               dd 0
end_initrd:                 dd 0
; Esta cadena NO está terminada, porque la termina la siguiente.
msg_cmdline_ok:           db 13, 10, '[KERNEL] cmdline OK='

; INITRAMFS/INITRD: si quitas "root=/dev/ram0"...
;msg_kernel_cmdline:  db "root=/dev/ram0 rw console=ttyS0 init=/init.sh", 0
;KERNEL_CMDLINE_SIZE  equ 46
;msg_kernel_cmdline:  db "rw console=ttyS0 init=/init.sh rdinit=/init.sh debug"
msg_kernel_cmdline:  db "rw init=/init.sh rdinit=/init.sh debug"
KERNEL_CMDLINE_SIZE  equ 39

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
