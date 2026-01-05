[BITS 16]
[ORG 0x7C00]

start:
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

    ; YA ESTAMOS en Modo Protegido
    mov si, pe_bit_set
    call debug_print_string16

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

    mov si, in_pm
    call debug_print_string16

    ; BACK TO UNREAL
    mov eax, cr0
    and eax, 0xfffe
    mov cr0, eax

    ; Salto para forzar vaciado de caché de instrucciones.
    ; DEBE SER UN FAR JUMP, pero nasm dará error si usamos far.
    jmp dword 0x0000:unreal_mode

unreal_mode:
    ; Restaurar registros de segmento a valores de Modo Real.
    ; [CRÍTICO] Si no hacemos esto, van a pasar cosas "raras". Por ejemplo,
    ; no funcionarán bien las interrupciones.
    mov ax, 0x0000
    mov ss, ax

    ; Si restauramos DS, ES, FS y GS, salimos totalmente de vuelta a Modo Real.
    ; NO ES LO QUE QUEREMOS, queremos permanecer en Modo Irreal.
    ; mov ds, ax
    ; mov es, ax
    ; mov fs, ax
    ; mov gs, ax

    mov si, in_unreal
    call debug_print_string16

    ; NULLIFICAR la secuencia
    ; - Para que la cadena ABCD termine en NULO en memoria.
    mov eax, 0x00000000
    mov [0x200004], eax

    mov eax, 0x44434241  ; DCBA (ABCD, little endian)
    mov [0x200000], eax  ; Escribimos por encima de 1MB!

    mov si, in_unreal_after_op
    call debug_print_string16

    mov ebx, [0x200000]
    cmp ebx, 0x44434241
    jne .mem_write_error

    ; OK
    mov si, in_unreal_after_debug
    call debug_print_string16

   ; Muestra un carácter en pantalla:
   mov bx, 0x0f03         ; Corazón :)
   mov eax, 0x0b8000      ; Este OFFSET es de 32 bits, ojo.
   mov word [ds:eax], bx

    mov esi, 0x200000     ; Ponemos en ESI la dirección donde hemos almacenado ABCD.
    ; ABCD en el serial (COM1)
    call debug_print_string16

    ; Demostramos que podemos usar de nuevo las interrupciones:
    ; ABCD en PANTALLA, no en serial.
    mov al, 0x41            ; A
    mov ah, 0x0E
    int 0x10

    mov al, 0x42            ; B
    mov ah, 0x0E
    int 0x10

    mov al, 0x43            ; C
    mov ah, 0x0E
    int 0x10

    mov al, 0x44            ; D
    mov ah, 0x0E
    int 0x10

    hlt
    jmp $

.mem_write_error:
    ; Mostramos el mensaje de error.
    mov si, in_unreal_debug_error
    call debug_print_string16

    hlt
    jmp $

%include "serial.asm"

; Una GDT básica preparada para entrar en Modo Protegido y salir de vuelta a (Ir)real.
gdt:
    ; Null descriptor
    dw 0x0000, 0x0000, 0x0000, 0x0000
    ; Code segment descriptor (base=0, limit=4GB, code segment, read/execute)
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF
    ; Data segment descriptor (base=0, limit=4GB, data segment, read/write)
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF

gdt_ref:
    dw gdt_end - gdt - 1    ; Limit of GDT
    dd gdt                  ; Base address of GDT
gdt_end:

; Definiciones y algunas variables.
DATA_SEG equ 0x10
CODE_SEG equ 0x08

pe_bit_set             db '[1] PONER PE BIT=1', 10, 13, 0
in_pm                  db '[2] EN MODO PROTEGIDO!', 10, 13, 0
in_unreal              db '[3] DE VUELTA A MODO (IR)REAL.', 10, 13, 0
in_unreal_after_op     db '[4] MODO IRREAL: operacion [OK]', 10, 13, 0
in_unreal_after_debug  db '[5] MODO IRREAL: CMP [OK]!', 10, 13, 0
in_unreal_debug_error  db '[5] MODO IRREAL: CMP [ERROR]!', 10, 13, 0
interrupciones_ok      db '[6] MODO IRREAL: IRQs OK!', 10, 13, 0
;*****************************************************************************
; //END
;*****************************************************************************
times 510-($-$$) db 0
dw 0xAA55