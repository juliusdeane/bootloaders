;*****************************************************************************
; Modo real, 16 bits, offset 0x8000
; - la posición donde cargamos estos sectores.
;*****************************************************************************
[BITS 16]
[ORG 0x8000]

;*****************************************************************************
; INICIO del código
;*****************************************************************************
stage2_start:
    call    init_com1  ; Inicializar COM1

    mov     si, msg_stage2_cargado
    call    debug_print_string16

    ; ACTIVAMOS A20
    ; Casi todos los micros nuevos arrancan con A20 activa...
    call enable_a20

    mov     si, msg_a20_activa
    call    debug_print_string16

    ; Cargamos la GDT32
    lgdt [gdt_ref]

    cli  ; Desactivamos interrupciones

    mov eax, cr0
    or  eax, 1  ; Establecemos el PE (Protection Enable) bit
    mov cr0, eax

    ; Limpiar cache de instrucciones.
    jmp .clear_instr_cache

.clear_instr_cache:
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

    jmp .unreal_mode

.unreal_mode:
    ; ¡Ahora estamos en UNREAL MODE!

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

    ; ¡DS, ES, FS, GS, SS todavía tienen los límites de 32-bit!
    ; Podemos acceder a memoria mayor.

    ; Ejemplo, mover valores de 32 bits.
    mov eax, 0x00000000
    mov [0x200004], eax  ; Poner BYTES NULOS cerrando el word 0x200000.

    mov eax, 0x44434241  ; DCBA
    mov [0x200000], eax  ; Write to physical address 2MB

    mov si, msg_modo_real_ok
    call debug_print_string16

    hlt
    jmp $
;*****************************************************************************
; //FIN del código
;*****************************************************************************

;*****************************************************************************
; INICIO de las funciones (las moveremos a otro archivo)
;*****************************************************************************
; Activar A20
enable_a20:
    pusha

    in al, 0x92         ; Leer del puerto del controlador del sistema
    or al, 2            ; Activar el bit A20
    out 0x92, al        ; Escribir de vuelta

    popa
    ret

%include "serial.asm"

; test_unreal_mode:
;     ; Ahora podemos acceder más allá de 1 MB usando direccionamiento de 32 bits
;    mov edi, 0x00110000     ; Dirección más allá de 1 MB (1 MB + 64 KB)
;    mov byte [edi], 0x42    ; Escribir un valor

    ; ¡Esto funciona en modo irreal pero no en modo real estándar!
;    ret
;*****************************************************************************
; //FIN de las funciones.
;*****************************************************************************

;*****************************************************************************
; INICIO Datos
;*****************************************************************************
DATA_SEG               equ 0x10
CODE_SEG               equ 0x08

msg_stage2_cargado db '[STAGE2] Cargado correctamente.', 13, 10, 13, 10, 0
msg_a20_activa     db '[STAGE2] [A20]            Activada correctamente.', 13, 10, 0
msg_gdt32_cargada  db '[STAGE2] [GDT32]          Cargada correctamente.', 13, 10, 0

msg_pre_jmp_pm     db '[STAGE2] [JMP .pm]        PRE salto a Modo Protegido.', 13, 10, 0
msg_pm_registros   db '[STAGE2] [PRE .pm]        Preparamos registros.', 13, 10, 0
msg_pm_pila        db '[STAGE2] [PRE .pm]        Preparamos PILA.', 13, 10, 0

msg_modo_protegido db '[STAGE2] [PROTECTED MODE] Activo.', 13, 10, 0
msg_modo_real_ok   db '[STAGE2] [unREAL MODE]    OK.', 13, 10, 0

%include "gdt32.asm"
;*****************************************************************************
; //FIN Datos
;*****************************************************************************
;*****************************************************************************
; PADDING + Signature:
; - para stage2 nos lo hemos inventado nosotros.
; - AAAA BBBB CCCC (12 bytes)
;*****************************************************************************
; 1024 - 12 bytes = 500
; 1024 (2 sectores) + MBR (1 sector) = 3 sectores.
times 1012-($-$$) db 0x90
db 0x41 ; A
db 0x41 ; A
db 0x41 ; A
db 0x41 ; A
db 0x42 ; A
db 0x42 ; A
db 0x42 ; A
db 0x42 ; A
db 0x43 ; C
db 0x43 ; C
db 0x43 ; C
db 0x43 ; C
