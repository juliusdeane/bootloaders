[BITS 32]

COM1   equ 0x03f8

init_com1_32:
    mov dx, COM1
    mov al, 0x00
    out dx, al                ; disable interrupts
    add dx, 1
    mov al, 0x80
    out dx, al                ; enable DLAB (set baud rate divisor)
    mov dx, 0x3F8
    mov al, 0x03
    out dx, al                ; divisor low byte (38400 baud si divisor=3)
    inc dx
    mov al, 0x00
    out dx, al                ; divisor high byte
    inc dx
    mov al, 0x03
    out dx, al                ; 8 bits, no parity, one stop bit
    inc dx
    mov al, 0xC7
    out dx, al                ; enable FIFO, clear, 14-byte threshold
    inc dx
    mov al, 0x0B
    out dx, al                ; IRQs enabled, RTS/DSR set

    ret


debug_print_string32:
    push eax
    push edx

    mov dx, COM1

.next_char:
    lodsb                    ; carga byte [ESI] en AL, avanza ESI
    test al, al
    jz .done                 ; fin de cadena (byte 0)

.wait_tx:
    in al, dx
    add dx, 5                ; LSR = base + 5
    in al, dx
    test al, 20h             ; bit 5: THR Empty (Transmitter Holding Register Empty)
    jz .wait_tx
    sub dx, 5                ; volver a base
    mov al, [esi-1]          ; recargar último carácter
    out dx, al
    jmp .next_char

.done:
    pop edx
    pop eax
    ret
