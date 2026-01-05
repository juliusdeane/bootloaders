[BITS 16]                  ; Modo real, 16bits
[ORG 0x7C00]               ; MBR en 0x7C00.

start:
    int 0xFF
    jmp $

times 510-($-$$) db 0x90   ; Pad con nop x 510 - tamaño del código.
; MAGIC NUMBER para que la BIOS identifique el loader.
dw 0xAA55




    int 11h          ; AX ahora contiene el mapa de equipamiento
    ; Ejemplo: verificar si hay coprocesador matemático
    test ax, 0002h   ; Bit 1 indica coprocesador
    jz no_copro      ; Salta si no hay