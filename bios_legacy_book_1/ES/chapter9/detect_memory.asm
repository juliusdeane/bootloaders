[BITS 16]

; Definir direcciones en lugar de reservar espacio
MEMORY_MAP_BUFFER equ 0x7E00    ; Justo después del bootloader
MEMORY_MAP_COUNT  equ 0x8500    ; Cualquier zona libre

detect_memory:
    pusha

    mov di, MEMORY_MAP_BUFFER
    xor ebx, ebx
    xor bp, bp
.loop:
    mov eax, 0xE820
    mov ecx, 24
    mov edx, 0x534D4150
    int 0x15
    jc .done
    cmp eax, 0x534D4150
    jne .done
    inc bp
    add di, 24
    test ebx, ebx
    jz .done
    cmp bp, 128
    jl .loop
.done:
    mov [MEMORY_MAP_COUNT], bp

    popa
    ret
