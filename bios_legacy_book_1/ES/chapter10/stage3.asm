[BITS 32]
[ORG 0x100000]

_start:
    ; Verificar CPUID extendido
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb no_long_mode

    ; Verificar bit de Long Mode
    mov eax, 0x80000001
    cpuid
    test edx, (1 << 29)
    jz no_long_mode

    ;*************************************************************************
    ; PAGINACIÓN: obligatorio para Modo Largo
    ;*************************************************************************
    ; Crear tabla de páginas Identity-mapped
    ; PML4 en 0x1000, PDPT en 0x2000, PD en 0x3000
    ;*************************************************************************
    ; Crear tabla de páginas que cubra al menos hasta 4MB
    ; PML4 en 0x1000, PDPT en 0x2000, PD en 0x3000
    ;*************************************************************************
    ; Limpiar áreas
    ; - prepara PML4
    mov edi, 0x1000
    mov cr3, edi
    ; Escribe 0 en 4096 dwords.
    xor eax, eax
    mov ecx, 4096
    rep stosd
    ; Restaura EDI desde CR3.
    mov edi, cr3

    ; PML4[0] -> PDPT
    mov dword [edi], 0x2003

    ; PDPT[0] -> PD
    mov dword [edi + 0x1000], 0x3003

    ; Mapear primeros 4MB con páginas de 2MB
    ; PD[0] -> 0-2MB
    mov dword [edi + 0x2000], 0x8B

    ; PD[1] -> 2MB-4MB
    ; - CUBRE 0x300000, donde cargaremos el kernel.
    mov dword [edi + 0x2008], 0x200083

    ; Podemos añadir más entradas si necesitamos más memoria.
    ; PD[2] -> 4MB-6MB
    mov dword [edi + 0x2010], 0x400083

    ; PD[3] -> 6MB-8MB (para el programa de usuario)
    mov dword [edi + 0x2018], 0x600083

    ; PD[4] -> 8MB-10MB (para el stack de usuario)
    mov dword [edi + 0x2020], 0x800083

    ;*************************************************************************
    ; Habilitar PAE
    ;*************************************************************************
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    ; Establecer bit LM en EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr

    ; Habilitar paginación
    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax

    ; Ahora estamos en "compatibility mode"
    ; Cargar GDT64 y saltar
    lgdt [gdt64_ptr]

    ; Necesitamos un salto largo a código de 64-bit
    jmp gdt64.code:start_long_mode

[BITS 64]
start_long_mode:
    ; ¡Ahora estamos en Modo Largo!
    mov ax, gdt64.data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov rsi, msg_lm_ok
    call debug_string_64

    ; Configurar stack
    mov rsp, 0x50000   ; stack

    ; KERNEL_ADDRESS => 0x300000
    ; - pero el entry point está en:
    ;00000000003008e8 T kernel_entry
    mov rax, KERNEL_ADDRESS
    add rax, 0x08e8
    call rax

    ; Si retorna (no debería): ERROR
.halt:
    cli
    hlt
    jmp .halt

    hlt
    jmp $
;*****************************************************************************
; // END: código principal.
;*****************************************************************************

;*****************************************************************************
; Código ERRORES
;*****************************************************************************
no_long_mode:
    mov esi, msg_no_long_mode
    call puts_serial
    hlt
    jmp $
    dw 'ERR1'
;*****************************************************************************
; //END: código ERRORES
;*****************************************************************************
%include "globals.asm"
%include "serial32.asm"
%include "serial64.asm"
%include "gdt64.asm"

;*****************************************************************************
; DATOS Y MENSAJES DE DEBUG:
;*****************************************************************************
CR_LF:                    db 13, 10, 0
SEPARATOR:
  times 79 db '='
  db 13, 10, 0

msg_no_long_mode:               db 13, 10, '[STAGE3] Modo Largo no disponible:(', 13, 10, 0
msg_lm_ok:                      db 13, 10, '[STAGE3] Modo Largo OK!', 13, 10, 0

;*****************************************************************************
; PADDING + Signature:
; - para stage3 otra firma propia.
; - DDDD CCCC BBBB AAAA (16 bytes)
;*****************************************************************************
; 8192 - 16 bytes = 8176
times 8176-($-$$) db 0x0
; Nuestra firma.
times 4 db 0x44
times 4 db 0x43
times 4 db 0x42
times 4 db 0x41
