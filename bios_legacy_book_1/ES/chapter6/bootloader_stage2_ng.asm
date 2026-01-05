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

    ; ==== ... === (79)
    call separator

    mov si, msg_stage2_ok
    call debug_print_string

    ; CRÍTICO: no olvidemos configurar el STACK:
    ; - preparamos la PILA.
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0x7C00      ; Stack crece hacia abajo desde 0x7C00.

    ; IMPORTANTE: no tocamos DS, ni ES. Los usaremos.
    ;*************************************************************************
    ; LEER EL (ENORME) KERNEL DE LINUX EN MEMORIA.
    ;*************************************************************************
    ; ==== ... === (79)
    call separator

    mov si, msg_kernel_begin_load
    call debug_print_string

    ; Esto es PRE stage2 de 16 sectores.
    ; mov eax, 9              ; sector inicial (final de stage2 en el disco).
    mov eax, 17               ; sector inicial (final de stage2 en el disco).
    xor edx, edx              ; sector inicial (parte alta)

    ; Original que nos dejaba en −909.328 bytes frente al STUB.
    ; mov cx, 29221                   ; total de sectores a leer.
    ; - hemos reducido unos 1600 para bajar ~800 Kb.
    mov cx, KERNEL_LOAD_SECTORS       ; total de sectores a leer.
    mov edi, KERNEL_LOAD_ADDRESS      ; ZONA ALTA DE MEMORIA (16 MB)

    push dword 0
    ; Aquí ponemos ES a 0.
    pop es

    ; copia a memoria alta.
    ; call read_sectors_to_high_mem
    ; Devuelve en EAX el total de bytes leídos.
    call read_sectors_to_high_mem_ng

    ; Si error...
    jc error_lectura_disco

    mov si, msg_total_bytes_read
    call debug_print_string
    mov ebx, eax
    call print_hex_serial

    mov si, msg_kernel_loaded
    call debug_print_string
    ;*************************************************************************
    ; //FIN: LEER EL (ENORME) KERNEL DE LINUX EN MEMORIA.
    ;*************************************************************************

    ;*************************************************************************
    ; DIAGNÓSTICO DEL KERNEL QUE HEMOS CARGADO
    ;*************************************************************************
    call kernel_staging_debug_values
    ;*************************************************************************
    ; //END: DIAGNÓSTICO DEL KERNEL QUE HEMOS CARGADO
    ;*************************************************************************

    ; Vamos a usar ESI para referenciar 0x1000000.
    mov edi, KERNEL_LOAD_ADDRESS  ; kernel_base (stagging)

    ;*************************************************************************
    ; VERIFICACIONES DE SALUD: que la versión sea la mínima aceptable.
    ; - verificar boot protocol version en staging.
    ;*************************************************************************
    mov ax, [edi + 0x206]        ; boot protocol version

    mov ebx, eax
    mov si, msg_kernel_bp_version
    call debug_print_string
    call print_hex_serial

    cmp ax, 0x0200   ; Necesitamos al menos 2.00
    jb bad_protocol  ; jump if below.
    ;*************************************************************************
    ; //END: VERIFICACIONES DE SALUD: que la versión sea la mínima aceptable.
    ;*************************************************************************

    ;*************************************************************************
    ; LEER NUESTRO INITRD EN MEMORIA.
    ; - vamos a usar las siguientes direcciones y valores de referencia:
    ; - Destino: 0x800000
    ;*************************************************************************
    call separator

    ; PRE: con stage2 de 8 sectores.
    ; mov eax, 14965664                ; Offset inicial de initrd en bytes.
    mov eax, INITRD_DISK_START_OFFSET  ; NG: offset inicial de initrd en bytes (16 sectores).
    mov dl, [boot_drive]               ; la unidad de disco de donde leer.
    mov ecx, INITRD_MAX_LENGTH         ; Tamaño máximo (protección) => 1.100.000

    ; 0x800000 + 1100000 => 90C8E0, SOBREESCRIBE SETUP DEL KERNEL?
    ; mov edi, 0x800000           ; a donde debe estar ubicado.
    mov edi, INITRD_LOAD_ADDRESS  ; nueva localización.
    ; [STAGING] [KERNEL] initrd_addr_max=[0x022c]:
    ; 7FFFFFFF
    ; NO VAMOS A TENER PROBLEMAS PORQUE ESTA ES LA DIRECCIÓN MÁXIMA
    ; DONDE PODEMOS UBICAR INITRD.

    mov [begin_initrd], edi

    push dword 0
    ; De nuevo ES a 0.
    pop es

    mov si, msg_initrd_begin_load
    call debug_print_string

    ; Leemos hasta la firma (12 bytes)
    call read_until_signature

    ; Si error...
    jc error_lectura_disco

    ; El total de bytes leídos de initrd.
    mov [initrd_bytes], eax
    add ecx, edi
    mov [end_initrd], ecx

    mov si, msg_total_bytes_read
    call debug_print_string
    mov ebx, eax
    call print_hex_serial

    ; Posición inicial INITRD:
    mov si, msg_initrd_begin
    call debug_print_string
    mov ebx, [begin_initrd]
    call print_hex_serial

    ; Posición final INITRD:
    mov si, msg_initrd_end
    call debug_print_string
    mov ebx, [end_initrd]
    call print_hex_serial

    ; INITRD cargado.
    mov si, msg_initrd_loaded
    call debug_print_string
    ;*************************************************************************
    ; //FIN: LEER NUESTRO INITRD EN MEMORIA.
    ;*************************************************************************

    ;*************************************************************************
    ; LINUX BOOT PROTOCOL:
    ; Seguimos el Linux Boot Protocol, usando 0x1000000 como staging
    ;
    ; PASO 0. Vamos a leer setup_sects
    ;*************************************************************************
    call separator

    mov si, msg_setup_load
    call debug_print_string

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
    mov ebx, eax
    mov si, msg_kernel_setup_sects
    call debug_print_string
    call print_hex_serial

    ; Paso 3.Calculamos setup_size
    inc eax                ; (setup_sects + 1)
    shl eax, 9             ; *512
    mov [setup_size], eax  ; aquí tenemos setup size.

    ; SETUP SIZE FINAL:
    mov si, msg_kernel_setup_size_final
    call debug_print_string
    mov ebx, [setup_size]
    call print_hex_serial

    ;*************************************************************************
    ; PASO 1: Copiar el SETUP del kernel a 0x90000
    ;*************************************************************************
    ; El setup son los primeros 0x5000 bytes del kernel que contienen código
    ; de inicialización en modo real/protegido
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

    call separator

    ; setup correctamente cargado.
    mov si, msg_setup_ok
    call debug_print_string

    mov si, msg_setup_copy_check
    call debug_print_string

    ; Una última comprobación de que hemos copiado correctamente.
    ; -en base + 0x200 = jmp 0x9026c
    ; - 0x90200:	jmp    0x9026c
    ; - EB 6A -> salto corto a 0x26c (jmp short +0x6A)
    mov esi, KERNEL_SETUP_ADDRESS
    movzx ebx, word [esi + 0x200]
    mov si, msg_setup_check_jmp
    call debug_print_string
    call print_hex_serial
    ; Debe mostrar: 00006AEB

    mov si, msg_setup_copy_check_ok
    call debug_print_string
    ;*************************************************************************
    ; PASO 2: Copiar el PAYLOAD del kernel a 0x90000
    ;*************************************************************************
    ; kernel: vmlinuz-6.8.0-86-generic
    ; ESTO ESTÁ MAL:
    ; Conocemos el tamaño exacto: 14961032
    ; 29221 * 512 = 14961152 (un poco más)
    ; mov ecx, (29221 * 512)
    ; mov ecx, 14961032      ; tamaño exacto
    ; sub ecx, [setup_size]  ; restamos el tamaño del setup.
    ; - debemos leer el tamaño de syssize!
    call separator

    ; El tamaño del payload es:
    ; Tamaño total - tamaño setup.
    ; Reafirmamos.
    mov esi, KERNEL_SETUP_ADDRESS
    mov eax, [esi + 0x1f4]  ; syssize = 0xE3F20 (desde el setup ya copiado)
    ; OJO que este NO es el definitivo. Este valor es en bloques de 16 bytes.
    ; Debemos multiplicarlo por 16.

    mov ebx, eax
    mov si, msg_kernel_syssize
    call debug_print_string
    call print_hex_serial

    ; Multiplicado x 16:
    shl eax, 4                 ; ×16 = 0xE3F200 bytes = 14.958.592 bytes
    mov [header_syssize], eax  ; Lo guardo en una variable por ahora.

    mov ebx, eax
    mov si, msg_kernel_syssize_shl
    call debug_print_string
    call print_hex_serial

    ; Ya lo teníamos, pero quiero ser cuidadoso.
    mov esi, KERNEL_LOAD_ADDRESS     ; kernel_base staging origen.
    add esi, [setup_size]            ; Sumamos a 0x1000000 el tamaño del setup (por ejemplo, 5000).
    mov [st_payload_start], esi      ; Almaceno en mi variable: (staging) payload_start.

    mov edi, KERNEL_PAYLOAD_ADDRESS  ; Ubicación destino del setup.
    add edi, [setup_size]
    mov [ru_payload_start], edi      ; Almaceno en mi variable: (running) payload_start.

    mov si, msg_payload_start_at
    call debug_print_string
    ; Staging at:
    mov ebx, [st_payload_start]
    call print_hex_serial
    ; Running at:
    mov ebx, [ru_payload_start]
    call print_hex_serial

    ; Por pura paranoia:
    ; - veamos qué hay en la dirección apuntada por st_payload_start:
    mov edi, [st_payload_start]
    mov ebx, [edi]
    call print_hex_serial
    ; A68DFAFC (jmp...)

    times 3 nop

    ; En nuestra versión anterior no teníamos ECX <=> dev ecx
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

    ; Terminado, mostramos mensaje de aviso.
    mov si, msg_payload_ok
    call debug_print_string

    ;*************************************************************************
    ; PASO 3: Kernel CMDLINE:
    ;*************************************************************************
    ; - CORRECTO: cmdline en 0x9a000 (aprox. hacia el final del heap)
    ; - CORRECTO: cmdline en 0x9e000 (más alta, pero más segura)

    call separator

    mov esi, msg_kernel_cmdline
    mov edi, KERNEL_CMDLINE_ADDRESS
    mov ecx, 5  ; auto\0
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

    ; Verificación: leer de vuelta
    mov ebx, [esi]  ; Debería tener 0x9e000
    call print_hex_serial
    call print_hex_screen

    ; Verificación: mostrar auto desde el destino.
    mov esi, dword KERNEL_CMDLINE_ADDRESS
    mov ebx, [esi]  ; Debería tener "auto" (6F747561, little endian)
    call print_hex_serial
    call print_hex_screen

    ; Imprimirá un mensaje de OK
    ; e inmediatamente añade "auto" (estça definida a continuación).
    ; No hemos terminado la cadena con 0:
    mov si, msg_cmdline_ok
    call debug_print_string
    ; por eso metemos salto de línea y retorno de carro con un 0 al final.
    mov si, CR_LF
    call debug_print_string
    ;*************************************************************************
    ; //END: Kernel CMDLINE:
    ;*************************************************************************

    ;*************************************************************************
    ; PASO 4: Ubicar Initrd: lo hemos leído antes.
    ;*************************************************************************
    ;   ramdisk_image  -> offset 0x218 (INITRD_LOAD_ADDRESS)
    ;   ramdisk_size   -> offset 0x21C (bytes leídos: [initrd_bytes])
    ;*************************************************************************
    call separator

    ; ERROR: sobreescribe el setup del kernel
    ; mov eax, 0x800000           ; EAX = valor a escribir => ramdisk_image
    mov eax, INITRD_LOAD_ADDRESS  ; EAX = valor a escribir => ramdisk_image
    mov edi, KERNEL_INITRD_PTR    ; EDI = dirección física destino
    mov [edi], eax                ; Escribir EAX en [EDI]

    ; Verificación: leer de vuelta
    mov ebx, [edi]               ; Debería tener INITRD_LOAD_ADDRESS
    call print_hex_serial
    call print_hex_screen

    mov eax, [initrd_bytes]       ; EAX = valor a escribir
    mov edi, KERNEL_INITRD_BYTES  ; EDI = dirección física destino
    mov [edi], eax                ; Escribir EAX en [EDI]

    ; Verificación: leer de vuelta
    mov ebx, [edi]               ; Debería tener [initrd_bytes]
    call print_hex_serial
    call print_hex_screen

    ;*************************************************************************
    ; PASO 5: Tipo de bootloader.
    ;*************************************************************************
    call separator

    mov eax, 0xff                    ; Bootloader indefinido
    mov edi, KERNEL_BOOTLOADER_TYPE  ; EDI = dirección física destino
    mov [edi], eax                   ; Escribir EAX en [EDI]

    ; Verificación: leer de vuelta
    mov si, msg_bootloader_check
    call debug_print_string

    mov ebx, [edi]               ; Debería tener 0xff
    call print_hex_serial
    call print_hex_screen

    ;*************************************************************************
    ; PASO 6: Configurar loadflags (CRÍTICO):
    ; - (ERROR que hemos cometido desde el principio).
    ;*************************************************************************
    call separator

    ; Configurar loadflags (1 byte)
    mov al, 0x81                 ; LOADED_HIGH (0x01) | CAN_USE_HEAP (0x80)
    mov edi, KERNEL_LOADFLAGS    ; Dirección destino
    mov [edi], al                ; Escribir 1 byte

    ; Verificación loadflags
    mov si, msg_loadflags_check
    call debug_print_string

    mov edi, KERNEL_LOADFLAGS
    movzx ebx, byte [edi]
    call print_hex_serial        ; Debería mostrar 00000081
    ;*************************************************************************
    ; //END: Configurar loadflags (CRÍTICO):
    ;*************************************************************************

    ;*************************************************************************
    ; PASO 7: heap end ptr:
    ;*************************************************************************
    call separator

    ; Configurar heap_end_ptr: lo fijamos nosotros.
    mov eax, 0x0009de00
    mov edi, KERNEL_HEAP_END_PTR
    mov [edi], eax  ; Heap termina en 0x9DE00

    ; Verificación heap_end_ptr
    mov si, msg_heap_end_check
    call debug_print_string

    mov edi, KERNEL_HEAP_END_PTR
    movzx ebx, word [edi]
    call print_hex_serial        ; Debería mostrar 0000DE0 (correcto)
    ;*************************************************************************
    ; //END: heap end ptr:
    ;*************************************************************************

    ;*************************************************************************
    ; PASO 8: Saltar al setup (POR FIN)
    ;*************************************************************************
    ; OK con el kernel.
    call separator

    mov si, msg_kernel_ready
    call debug_print_string

    times 4 nop

    ; Detenemos las IRQ.
    cli

    ; Preparamos correctamente los segmentos.
    mov ax, 0x9000
    mov ds, ax

    ;*************************************************************************
    ; DIAGNÓSTICO DEL KERNEL QUE VAMOS A EJECUTAR
    ;*************************************************************************
    ; RUNNING asume que DS está ya establecido a 0x9000.
    call kernel_running_debug_values
    ;*************************************************************************
    ; //END: DIAGNÓSTICO DEL KERNEL QUE VAMOS A EJECUTAR
    ;*************************************************************************

    ;*************************************************************************
    ; COMPLETAR REGISTROS DE SEGMENTO Y A POR EL SALTO:
    ;*************************************************************************
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0xffff

    ;*************************************************************************
    ; BEGIN: CINCO nops seguidos para localizarlos visualmente y parar.
    ;*************************************************************************
    times 5 nop
    ;*************************************************************************
    ; //END: CINCO nops seguidos para localizarlos visualmente y parar.
    ;*************************************************************************

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
%include "kernel_extra_debug.asm"

;*****************************************************************************
; DATOS Y MENSAJES DE DEBUG:
;*****************************************************************************
CR_LF:                    db 13, 10, 0
SEPARATOR:
  times 79 db '='
  db 13, 10, 0

msg_stage2_ok:            db '[STAGE2] Corriendo OK!', 13, 10, 0

msg_total_bytes_read:     db '[STAGE2] [DISK] Total bytes:', 13, 10, 0
msg_disk_error:           db '[STAGE2] Error de disco:', 13, 10, 0

%include "kernel_header_msgs.asm"

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

; msg_kernel_cmdline:  db "root=/dev/ram0 rw console=ttyS0", 0
msg_kernel_cmdline:       db "auto", 0
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
