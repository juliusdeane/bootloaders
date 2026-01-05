;*****************************************************************************
; print_string
;*****************************************************************************
; Imprimir con int 10h
print_string:
    push ax
    push bx
    mov ah, 0x0e           ; BIOS teletype
.loop:
    lodsb                  ; Cargamos un byte desde [SI] en AL
    test al, al            ; ¿Es 0?
    jz .done               ; ¿Si es 0, jump a .done (hecho)
    int 0x10               ; print
    jmp .loop
.done:
    pop bx
    pop ax
    ret

;*****************************************************************************
; Sub: clear_screen
;*****************************************************************************
; Borra la pantalla y pone el modo de video 10h
clear_screen:
    mov ah, 0x00    ; 00: poner modo de video
    mov al, 0x03    ; Modo 3: texto 80x25, 16 colores
    int 0x10

    ; Poner background y foreground (colores)
    mov ah, 0x06    ; Clear / scroll screen up function
    xor al, al      ; Número de líneas para hacer scroll (0h pantalla completa)
    xor cx, cx      ; Row,column de la esquina superior izq.
    mov dx, 0x184f  ; Row,column de la esquina inferior derech.
    mov bh, 0x4f    ; Colores Background/foreground: https://en.wikipedia.org/wiki/BIOS_color_attributes
    int 0x10
    ret

;*****************************************************************************
; wait_key
;*****************************************************************************
; - Espera una tecla
wait_key:
    pusha

    mov ah, 0x00
    int 0x16

    popa
    ret
