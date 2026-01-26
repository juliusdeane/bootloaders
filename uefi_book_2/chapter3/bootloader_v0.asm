;*****************************************************************************
; Fuente para FASM.
; - fasm bootloader_v0.asm (con uefi.inc).
; - imprime "Hola mundo" y retorna (sale).
;*****************************************************************************
format pe64 efi  ; Formato de aplicación EFI de 64 bits
entry main       ; Entry point.

section '.text' code executable readable

; La renombramos a uefi.asm:
include 'uefi.asm'

main:
    ; initialize UEFI library
    InitializeLib
    jc @f

    ; call uefi function to print to screen
    uefi_call_wrapper ConOut, OutputString, ConOut, _hola_mundo

    ; Retornar EFI_SUCCESS (0)
    ; xor rax, rax
@@: mov eax, EFI_SUCCESS

    ; 7. Bucle infinito para evitar que el programa termine inmediatamente
    jmp $  ; Bucle infinito
    ;retn


section '.data' data readable writeable

; Cadena "Hola mundo" en UCS-2 (caracteres de 16 bits), terminada en nulo (0)
; - esto va a ser muy importante posteriormente, recuerda UCS-2.
_hola_mundo:
    du 'Hola mundo.', 0xD, 0xA, 0

; UEFI spec requiere tener .reloc.
section '.reloc' fixups data readable discardable
