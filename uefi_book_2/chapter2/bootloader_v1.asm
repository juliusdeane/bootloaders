;*****************************************************************************
; Fuente para FASM.
; - fasm bootloader_v1.asm
; - imprime "Hola mundo" y retorna (sale).
;*****************************************************************************
format pe64 efi  ; Formato de aplicación EFI de 64 bits
entry main       ; Entry point.

; Definiciones de offsets (simplificadas, es mejor usar 'struc' pero
; para un ejemplo simple con offsets constantes funciona)
EFI_SYSTEM_TABLE_ConOut = 64             ; Offset a ConsoleOut en EFI_SYSTEM_TABLE (0x40)
EFI_SIMPLE_TEXT_OUTPUT_OutputString = 8  ; Offset a OutputString en EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL

section '.text' code readable executable

main:
    ; EFI_SYSTEM_TABLE:
    ; - RDX = SystemTable

    ; 1. Obtener la dirección del protocolo ConOut (Console Output)
    ; - ConOut está en EFI_SYSTEM_TABLE + 64 bytes (0x40)
    mov rcx, [rdx + EFI_SYSTEM_TABLE_ConOut]

    ; 2. Obtener la dirección de la función OutputString
    ; OutputString es el segundo campo del protocolo ConOut (offset 8)
    mov rax, [rcx + EFI_SIMPLE_TEXT_OUTPUT_OutputString]

    ; 3. Preparar los argumentos para OutputString:
    ; Arg 1 (RCX): Puntero al protocolo ConOut (ya está en rcx)
    ; Arg 2 (RDX): Puntero a la cadena de texto UCS-2/UTF-16LE
    lea rdx, [_hola_mundo]               ; rdx = Dirección de la cadena

    ; 4. Ajustar el stack para la llamada de función (convención de llamada x64)
    sub rsp, 32                          ; Espacio sombra de 32 bytes

    ; 5. Llamar a la función OutputString
    call rax                             ; Llama a la función OutputString

    ; 6. Restaurar el stack
    add rsp, 32

    ; 7. Bucle infinito para evitar que el programa termine inmediatamente
    ; jmp $                              ; Bucle infinito
    ret

section '.data' data readable writeable
; Cadena "Hola mundo" en UCS-2 (caracteres de 16 bits), terminada en nulo (0)
; - esto va a ser muy importante posteriormente, recuerda UCS-2.
_hola_mundo:
    du 'Hola mundo.', 0xD, 0xA, 0
