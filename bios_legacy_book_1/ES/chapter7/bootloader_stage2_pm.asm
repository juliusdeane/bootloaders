[BITS 16]
[ORG 0x8000]


stage2_start:
    mov [boot_drive], dl

    ; Seguimos en Modo Real: DETECTAMOS MEMORIA DISPONIBLE
    call detect_memory

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

    ;*************************************************************************
    ; KERNEL:
    ;*************************************************************************
    ; Desde aquí, proceso de carga del kernel desde Modo Protegido.
    ;
    ; KERNEL_LOAD_ADDRESS=0x5000000
    ; MUCHO MÁS ARRIBA: estábamos sobreescribiendo cosas...
    ;*************************************************************************
    ; Leo el contenido del KERNEL en memoria.
    mov eax, KERNEL_START_SECTOR    ; Sector inicial (LBA)
    ; Número de sectores a leer: KERNEL_SIZE_SECTORS + 400 sectores de margen
    mov ecx, KERNEL_SIZE_SECTORS + 400
    mov edi, KERNEL_LOAD_ADDRESS    ; Dirección destino (puede ser > 1 MB)
    xor edx, edx
    mov dl, [boot_drive]            ; Asegurar EDX limpio (precaución)

    call read_sectors_pm

    ; Si error...
    jc error_kernel_read

    mov [kernel_read_sectors], eax
    shl eax, 9  ; x 512 = bytes
    mov [kernel_read_bytes], eax

    ;*************************************************************************
    ; VERIFICACIONES DE SALUD: que la versión sea la mínima aceptable.
    ; - verificar boot protocol version en staging.
    ;*************************************************************************
    mov edi, KERNEL_LOAD_ADDRESS  ; kernel_base (staging)
    mov ax, [edi + 0x206]         ; boot protocol version
    cmp ax, 0x0200                ; Necesitamos al menos 2.00
    jb bad_protocol

    ; setup_sects está en offset 0x1F1
    ; - ya conocemos esta lógica.
    xor eax, eax
    mov al, byte [edi + 0x1f1]
    test al, al
    jnz .setup_size_ok
    mov al, 4                       ; Default: 4 sectores
.setup_size_ok:
    add al, 1                       ; +1 por el sector de boot
    movzx eax, al                   ; Extender a 32-bit
    shl eax, 9                      ; Multiplicar por 512 (tamaño sector)

    ; Ahora EAX = tamaño del setup en bytes
    ; Copiar desde [KERNEL_LOAD_ADDRESS + EAX] hacia KERNEL_ENTRY_ADDRESS
    mov esi, KERNEL_LOAD_ADDRESS
    add esi, eax                    ; Fuente: después del setup

    ; 3. Cargar tamaño a copiar
    mov ecx, [kernel_read_bytes]      ; Tamaño TOTAL del archivo
    sub ecx, eax                     ; Restar tamaño del setup

    ; 4. Copiar a destino
    mov edi, KERNEL_ENTRY_ADDRESS  ; Destino al que saltaremos.
    shr ecx, 2                     ; Dividir entre 4 (copiar DWORDs)
    rep movsd                      ; ← Usa MOVSD, no MOVSL
    ; Si OK...

    ;*************************************************************************
    ; INITRD:
    ;*************************************************************************
    ; Leo el contenido de INITRD en memoria.
    ;*************************************************************************
    mov eax, INITRD_START_SECTOR    ; Sector inicial (LBA)
    ; Número de sectores a leer: INITRD_SIZE_SECTORS
    mov ecx, INITRD_SIZE_SECTORS+10
    mov edi, INITRD_LOAD_ADDRESS
    xor edx, edx
    mov dl, [boot_drive]

    call read_sectors_pm

    ; Si error...
    jc error_initrd_read
    ;*************************************************************************
    ; VERIFICACIONES DE SALUD: hemos copiado correctamente initrd.
    ;*************************************************************************
    ; Si OK...
    mov [initrd_read_sectors], eax  ; sectors
    shl eax, 9
    mov [initrd_read_bytes], eax  ; bytes

    mov edi, INITRD_LOAD_ADDRESS  ; initrd base
    mov ax, word [edi]            ; CPIO magic: 1f 8b
    cmp ax, 0x8b1f
    jb bad_initrd_sig

    ;*************************************************************************
    ; [!!!] Boot Protocol, pero para Modo Protegido.
    ;*************************************************************************
    ; PASO 0. Preparar estructura - boot_params
    ;*************************************************************************
    ; Inicializar a cero los 4KB de memoria reservados por resb
    mov edi, KERNEL_BOOT_PARAMS
    mov ecx, 0x1000      ; 4096 bytes (4KB)
    xor eax, eax
    rep stosb            ; Llenar con ceros
    ; boot_params preparado.

    ; Vamos a copiar el header a boot_params:
    ; - ubicamos el header.
    mov esi, KERNEL_LOAD_ADDRESS
    add esi, 0x1f1       ; Offset del header del kernel
    ; - ubicamos el destino.
    mov edi, KERNEL_BOOT_PARAMS
    add edi, 0x1f1            ; boot_params también tiene el header en 0x1F1
    mov ecx, (0x290 - 0x1f1)  ; Tamaño del header
    rep movsb                 ; Copiar header

    ;*************************************************************************
    ; PASO 1.a RELLENAMOS LOS CAMPOS OBLIGATORIOS DE boot_params:
    ;*************************************************************************
    ; Base de boot_params
    mov edi, KERNEL_BOOT_PARAMS

    ; type_of_loader (offset 0x210)
    mov byte [edi + 0x210], 0xff    ; 0xFF = bootloader personalizado

    ; Verificar que loadflags tenga CAN_USE_HEAP (bit 7)
    ; - Ya está copiado del header, pero podemos modificarlo si es necesario.
    ; heap_end_ptr (offset 0x224) - opcional pero recomendado
    mov word [edi + 0x224], 0xde00  ; Espacio para heap del setup

    ; cmd_line_ptr (offset 0x228)
    ; - dirección donde va la cmdline, OJO que todavía no la hemos copiado.
    mov dword [edi + 0x228], KERNEL_CMDLINE_ADDRESS

    ; ramdisk_image (offset 0x218)
    mov dword [edi + 0x218], INITRD_LOAD_ADDRESS  ; Donde tenemos initrd

    ; ramdisk_size (offset 0x21C)

    mov eax, INITRD_SIZE_BYTES
    mov dword [edi + 0x21c], eax

    ; kernel_alignment (offset 0x230)
    mov dword [edi + 0x230], 0x1000000  ; 16MB alineación (típico)

    ; code32_start (offset 0x214) - Punto de entrada
    ; 0x100000 también es funcional y, a veces, es mucho más simple apuntar aquí.
    ; mov dword [edi + 0x214], 0x100000
    mov dword [edi + 0x214], KERNEL_ENTRY_ADDRESS   ; Entrada en modo protegido

    ;*************************************************************************
    ; PASO 1.b Rellenamos campos opcionales de boot_params:
    ;*************************************************************************
    mov edi, KERNEL_BOOT_PARAMS

    ; ext_loader_ver (offset 0x226)
    mov byte [edi + 0x226], 0    ; Versión del loader extendido

    ; ext_loader_type (offset 0x227)
    mov byte [edi + 0x227], 0    ; Tipo de loader extendido

    ; setup_data (offset 0x250) - lista enlazada de datos setup
    mov dword [edi + 0x250], 0   ; NULL si no hay datos extra

    ; pref_address (offset 0x258) - dirección preferida del kernel
    ; mov dword [edi + 0x258], 0x1000000  ; 16MB típicamente
    ; - lo hemos hecho antes es leerlo del kernel header, pero como ya la
    ;   tenemos claro, la fijamos.
    mov dword [edi + 0x258], KERNEL_LOAD_ADDRESS
    mov dword [edi + 0x25c], 0          ; parte alta (64-bit)

    ;*************************************************************************
    ; PASO 2. copiamos la kernel cmd_line
    ;*************************************************************************
    ; Escribir la línea de comandos en 0x20000 (ejemplo)
    mov esi, kernel_cmdline
    mov edi, KERNEL_CMDLINE_ADDRESS
.copy_cmdline:
    lodsb
    stosb
    test al, al
    jnz .copy_cmdline

    ;*************************************************************************
    ; PASO 3. Mapa de memoria adecuado para el kernel de PM
    ;*************************************************************************
    call setup_e820_in_boot_params
    ;mov edi, KERNEL_BOOT_PARAMS
    ;mov byte [edi + 0x1E8], 3              ; 3 entradas E820

    ; Entrada 1: 0-640KB (usable)
    ;mov edi, 0x10000
    ;add edi, 0x2D0
    ;mov dword [edi + 0], 0x00000000        ; base low
    ;mov dword [edi + 4], 0x00000000        ; base high
    ;mov dword [edi + 8], 0x0009FC00        ; size low (639KB)
    ;mov dword [edi + 12], 0x00000000       ; size high
    ;mov dword [edi + 16], 1                ; type: usable

    ; Entrada 2: 1MB-16MB (usable) - CONSERVADOR
    ;add edi, 20
    ;mov dword [edi + 0], 0x00100000        ; base: 1MB
    ;mov dword [edi + 4], 0x00000000
    ;mov dword [edi + 8], 0x00F00000        ; size: 15MB (conservador)
    ;mov dword [edi + 12], 0x00000000
    ;mov dword [edi + 16], 1                ; type: usable

    ; Entrada 3: 16MB+ reservado (para evitar problemas)
    ;add edi, 20
    ;mov dword [edi + 0], 0x01000000        ; base: 16MB
    ;mov dword [edi + 4], 0x00000000
    ;mov dword [edi + 8], 0x7F000000        ; size: resto
    ;mov dword [edi + 12], 0x00000000
    ;mov dword [edi + 16], 2                ; type: RESERVED (no usar)

    ; e820_entries (offset 0x1E8) - número de entradas
    ; - vamos a trampear esto: como va a ser el kernel el que se encargue de la
    ;   memoria luego, sobra con dos entradas muy simples para lograr que arranque.
    ;mov byte [edi + 0x1e8], 2
    ; Apuntar a la zona del mapa E820 (base + 0x2d0)
    ;add edi, 0x2d0
    ; Entrada 1: Primeros 640KB (memoria baja convencional)
    ;mov dword [edi + 0], 0x00000000    ; base: 0
    ;mov dword [edi + 4], 0x00000000
    ;mov dword [edi + 8], 0x0009FC00    ; size: 640KB
    ;mov dword [edi + 12], 0x00000000
    ;mov dword [edi + 16], 1            ; tipo: usable

    ; Entrada 2: Desde 1MB en adelante (memoria extendida)
    ;add edi, 20
    ;mov dword [edi + 0], 0x00100000    ; base: 1MB
    ;mov dword [edi + 4], 0x00000000
    ;mov dword [edi + 8], 0x0FF00000    ; size: 255MB (ejemplo generoso)
    ;mov dword [edi + 12], 0x00000000
    ;mov dword [edi + 16], 1            ; tipo: usable

    ; INCLUSO MÁS SIMPLE TODAVÍA, con una sola entrada:
    ; mov edi, KERNEL_BOOT_PARAMS
    ; mov byte [edi + 0x1E8], 1    ; Solo 1 entrada
    ; Apuntar a la zona del mapa E820 (base + 0x2d0)
    ; add edi, 0x2d0
    ; mov dword [edi + 0], 0x00100000    ; base: 1MB
    ; mov dword [edi + 4], 0x00000000
    ; mov dword [edi + 8], 0x3F000000    ; size: ~1GB
    ; mov dword [edi + 12], 0x00000000
    ; mov dword [edi + 16], 1            ; tipo: usable

    ;*************************************************************************
    ; PASO X. Preparamos y saltamos al kernel.
    ;*************************************************************************
    cli

    ; Obligatorio: esi debe tener la ubicación de boot_params,
    ; - ebp, edi y ebx deben ser 0.
    mov esi, KERNEL_BOOT_PARAMS
    xor ebp, ebp
    xor edi, edi
    xor ebx, ebx

    ; Preparamos correctamente los segmentos.
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    jmp CODE_SEG:KERNEL_ENTRY_ADDRESS
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

error_kernel_read:
    mov esi, msg_kernel_read_error
    call puts_serial

    hlt
    jmp $
    dw 'ERR2'

error_initrd_read:
    mov esi, msg_initrd_read_error
    call puts_serial

    mov ebx, edx
    call print_hex_serial

    hlt
    jmp $
    dw 'ERR3'

bad_initrd_sig:
    mov esi, msg_initrd_sig_error
    call puts_serial

    hlt
    jmp $
    dw 'ERR4'

bad_protocol:
    mov esi, msg_kernel_bad_boot_protocol
    call puts_serial

    hlt
    jmp $
    dw 'ERR5'
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

; Usando times n db, aumenta el tamaño del stage2.
;boot_params:                    times 4096 db 0
; Con resb movemos el puntero, pero no ocupamos espacio en stage2.
;boot_params:                    resb 4096
; pero hemos optado por hacerlo dinámicamente.
kernel_read_sectors:            dd 0
kernel_read_bytes:              dd 0

initrd_read_sectors:            dd 0
initrd_read_bytes:              dd 0

kernel_cmdline:      db "console=tty0 rw rdinit=/init.sh"
;                     db " earlyprintk=serial,ttyS0,115200 console=ttyS0,115200 loglevel=8 debug"
                     db " earlyprintk=serial,ttyS0,115200 earlyprintk=vga loglevel=8 debug"
                     db " keep_bootcon console=tty0", 0

msg_pm_bad_gdt:                 db 13, 10, '[STAGE2] GDT Incorrecta :(', 13, 10, 0
msg_pm_ok:                      db 13, 10, '[STAGE2] Modo protegido OK!', 13, 10, 0
msg_kernel_read_ok:             db 13, 10, '[STAGE2] [KERNEL] Fichero de kernel cargado!', 13, 10, 0
msg_kernel_read_error:          db 13, 10, '[STAGE2] [KERNEL] Error de lectura del fichero de kernel :(', 13, 10, 0
msg_kernel_bad_boot_protocol:   db 13, 10, '[STAGE2] [KERNEL] Boot Protocol no soportado :(', 13, 10, 0
msg_initrd_read_ok:             db 13, 10, '[STAGE2] [INITRD] Fichero de initrd cargado!', 13, 10, 0
msg_initrd_read_error:          db 13, 10, '[STAGE2] [INITRD] Error de lectura del fichero de initrd :(', 13, 10, 0
msg_initrd_sig_error:           db 13, 10, '[STAGE2] [INITRD] Error de firma de initrd (0x8b1f) :(', 13, 10, 0

msg_go_kernel:                  db 13, 10, '[STAGE2] Saltando: el kernel tiene el control ahora!', 13, 10, 0
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
