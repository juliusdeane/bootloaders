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
    mov si, mensaje_press_key
    call print_string16
    call wait_key

    ; Primer modo: uno SEGURO que funciona.
    ; Modo 0x13: 320x200x8 (sin VBE)
    mov ax, VIDEO_MODE
    int 0x10

    ; El framebuffer en modo 0x13 SIEMPRE está en 0xA0000
    mov ax, FRAMEBUFFER_ADDR
    mov es, ax

    ; Dibujar píxeles desde la esquina superior
    xor di, di

    mov al, 1  ; Azul
    ; 40 líneas en azul
    mov cx, 12800
    rep stosb

    mov al, 2  ; Verde
    ; 40 líneas en verde
    mov cx, 12800
    rep stosb

    mov al, 3  ; Cyan
    ; 40 líneas en cyan
    mov cx, 12800
    rep stosb

    mov al, 4  ; Rojo
    ; 40 líneas en rojo
    mov cx, 12800
    rep stosb

    mov al, 5  ; Magenta
    ; 40 líneas en magenta
    mov cx, 12800
    rep stosb

    ; Como estamos en un modo gráfico, mostramos el mensaje en COM1
    mov si, mensaje_press_key
    call debug_print_string16
    call wait_key

    ; Limpiar pantalla en modo 0x13 con color GRIS CLARO.
    mov ax, FRAMEBUFFER_ADDR
    mov es, ax
    xor di, di

    ; Preparar 4 bytes de color gris claro (7 en paleta VGA estándar)
    ; 0x7 0x7 0x7 0x7
    ; - estamos haciendo un poco de trampa,
    ; ¡porque usamos un registro de 32 bits!
    ; (recuerda que podemos con el prefijo 0x60)
    mov eax, 0x07070707  ; 4 píxeles

    ; 320x200 = 64000 bytes = 16000 dwords
    mov cx, 16000
    rep stosd           ; Escribe 2 bytes a la vez

    ; Vamos a dibujar una  circunferencia.
    ; Parámetros del circunferencia
    mov word [centro_x], 160
    mov word [centro_y], 100
    mov word [radio_ext], 50      ; Radio exterior
    mov word [radio_int], 40      ; Radio interior (50-10=40)

    ; Recorrer toda la pantalla
    mov word [y], 0

.loop_y:
    mov word [x], 0

.loop_x:
    ; Calcular dx = x - centro_x
    mov ax, [x]
    sub ax, [centro_x]
    mov [dx_val], ax

    ; Calcular dy = y - centro_y
    mov ax, [y]
    sub ax, [centro_y]
    mov [dy_val], ax

    ; Calcular distancia² = dx² + dy²
    mov ax, [dx_val]
    imul ax              ; AX = dx²
    mov bx, ax

    mov ax, [dy_val]
    imul ax              ; AX = dy²
    add bx, ax           ; BX = dx² + dy²

    ; Comparar con radio_int² y radio_ext²
    mov ax, [radio_int]
    imul ax              ; AX = radio_int²
    cmp bx, ax
    jl .skip             ; Si dist² < radio_int², saltar

    mov ax, [radio_ext]
    imul ax              ; AX = radio_ext²
    cmp bx, ax
    jg .skip             ; Si dist² > radio_ext², saltar

    ; Dibujar pixel negro
    call dibujar_pixel

.skip:
    inc word [x]
    cmp word [x], 320
    jl .loop_x

    inc word [y]
    cmp word [y], 200
    jl .loop_y

    hlt
    jmp $
;*****************************************************************************
; //FIN del código
;*****************************************************************************

;*****************************************************************************
; INICIO de las funciones (las moveremos a otro archivo)
;*****************************************************************************
; Imprimir texto en pantalla.
print_string16:
    pusha
    mov ah, 0x0e        ; Teletype output
.loop:
    lodsb               ; Load byte from SI into AL
    cmp al, 0           ; Check for null terminator
    je .done
    int 0x10            ; Print character
    jmp .loop
.done:
    popa
    ret

; Imprimir texto en COM1.
debug_print_string16:
    ; Imprimimos el contenido de la cadena de texto en si, a través del COM1.
    ; Protegemos los registros en la pila.
    pusha

.debug_print_string16_loop:
    lodsb
    test al, al
    jz .debug_print_string16_done

    mov dx, 0x3F8
    out dx, al
    jmp .debug_print_string16_loop

.debug_print_string16_done:
    popa
    ret

; Espera pulsación de una tecla.
wait_key:
    pusha

    mov ah, 0x00
    int 0x16

    popa
    ret

; Función para dibujar un pixel
dibujar_pixel:
    pusha

    ; offset = y * 320 + x
    mov ax, [y]
    mov bx, 320
    mul bx              ; AX = y * 320
    add ax, [x]         ; AX = y * 320 + x
    mov di, ax

    mov byte [es:di], 0  ; Color negro

    popa
    ret
;*****************************************************************************
; //FIN de las funciones.
;*****************************************************************************

;*****************************************************************************
; INICIO Datos
;*****************************************************************************
VIDEO_MODE         equ 0x0013
FRAMEBUFFER_ADDR   equ 0xA000

mensaje_press_key   db 'Pulsa una tecla para continuar...', 13, 10, 0

; Variables para el círculo.
centro_x:   dw 0
centro_y:   dw 0
radio_ext:  dw 0
radio_int:  dw 0
x:          dw 0
y:          dw 0
dx_val:     dw 0
dy_val:     dw 0
;*****************************************************************************
; //FIN Datos
;*****************************************************************************
;*****************************************************************************
; Signature:
; - para stage2 nos lo hemos inventado nosotros.
; - AAAA BBBB CCCC (12 bytes)
;*****************************************************************************
; PADDING de nuevo:
; este stage2 es muy pequeño, unos 142 bytes.
times 500-($-$$) db 0

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
