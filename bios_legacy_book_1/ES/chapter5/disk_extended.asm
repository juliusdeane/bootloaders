; Para poder escribir dentro de 1MB con int 13h
BUFFER_LOW equ 0x10000      ; Buffer temporal (64KB)

;*****************************************************************************
; BEGIN: función para leer sectores del disco.
;*****************************************************************************
read_sectors_lba:
    pushad

    ; Usar registros directamente, guardando lo necesario
    mov ebp, eax        ; EBP = LBA actual
    ; Sector donde iniciamos: lo pasamos en eax como parámetro

    mov esi, edx        ; ESI = LBA high (normalmente 0)
    ; CX ya tiene num_sectors (número de sectores a leer).
    ; DL ya tiene drive (unidad de disco)
    ; ES:DI ya tiene buffer (zona de memoria donde copiamos)

    ; FORZAR 1 sector.
    mov cx, 1

.read_loop:
    ; Preparar DAP en la pila
    push dword 0                    ; LBA high
    push ebp                        ; LBA low
    push es                         ; Segmento
    push di                         ; Offset
    push word 1                     ; 1 sector
    push word 0x10                  ; Tamaño DAP

    ; DS:SI = DAP
    push ss
    pop ds
    mov si, sp

    ; INT 13h Extended Read
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13

    ; Guardar resultado
    pushf
    add sp, 16                      ; Limpiar DAP
    popf
    jc .error

    ; Siguiente sector
    inc ebp
    add di, 512
    jnc .no_wrap

    ; Ajustar ES si DI hizo wrap
    mov bx, es
    add bx, 0x1000
    mov es, bx

.no_wrap:
    loop .read_loop                 ; CX-- automático

    clc
    jmp .done

.error:
    mov si, msg_disk_error
    call debug_print_string16
    stc

.done:
    popad
    ret
;*****************************************************************************
; //END: final función para leer sectores del disco.
;*****************************************************************************

;*****************************************************************************
; BEGIN: función para leer sectores del disco.
; - esta versión imprime u + por cada sector leído.
;*****************************************************************************
read_sectors_lba_status:
    pushad

    ; Usar registros directamente, guardando lo necesario
    mov ebp, eax        ; EBP = LBA actual
    ; Sector donde iniciamos: lo pasamos en eax como parámetro
    mov esi, edx        ; ESI = LBA high (normalmente 0)
    ; CX ya tiene num_sectors (número de sectores a leer).
    ; DL ya tiene drive (unidad de disco)
    ; ES:DI ya tiene buffer (zona de memoria donde copiamos)

.read_loop:
    ; Preparar DAP en la pila
    push dword 0                    ; LBA high
    push ebp                        ; LBA low
    push es                         ; Segmento
    push di                         ; Offset
    push word 1                     ; 1 sector
    push word 0x10                  ; Tamaño DAP

    ; DS:SI = DAP
    push ss
    pop ds
    mov si, sp

    ; INT 13h Extended Read
    mov ah, 0x42
    int 0x13

    ; Guardar resultado
    pushf
    add sp, 16                      ; Limpiar DAP
    popf
    jc .error

    ;*************************************************************************
    ; STATUS: MOSTRAR '+' POR CADA SECTOR LEÍDO
    ;*************************************************************************
    push ax
    push bx
    mov al, '+'
    mov ah, 0x0E
    mov bx, 0x0007
    ; Alternativa con colores:
    ; mov bl, 0x0A        ; Verde brillante
    ; mov bh, 0x00        ; Página 0
    int 0x10
    pop bx
    pop ax
    ;*************************************************************************

    ; Siguiente sector
    inc ebp
    add di, 512
    jnc .no_wrap

    ; Ajustar ES si DI hizo wrap
    mov bx, es
    add bx, 0x1000
    mov es, bx

.no_wrap:
    loop .read_loop                 ; CX-- automático

    clc
    jmp .done

.error:
    mov si, msg_disk_error
    call debug_print_string16
    stc

.done:
    popad
    ret
;*****************************************************************************
; //END: final función para leer sectores del disco.
; - con status (+)
;*****************************************************************************

;*****************************************************************************
; BEGIN: función para leer sectores del disco.
; - esta versión imprime u + por cada sector leído.
;*****************************************************************************
read_sectors_lba_fast:
    pushad

    mov ebp, eax        ; LBA inicial
    mov esi, edx        ; LBA high

    ; CX = sectores totales
    mov [.total_sectors], cx

.read_loop:
    ; Calcular cuántos sectores leer en este bloque (máximo 127)
    mov ax, cx
    cmp ax, 127
    jle .use_remaining
    mov ax, 127         ; Leer máximo 127 sectores por vez

.use_remaining:
    mov [.sectors_this_block], ax

    ; Preparar DAP
    push dword 0                    ; LBA high
    push ebp                        ; LBA low
    push es                         ; Segmento
    push di                         ; Offset
    push ax                         ; ⭐ Sectores a leer (ya no es 1)
    push word 0x10                  ; Tamaño DAP

    push ss
    pop ds
    mov si, sp

    ; INT 13h Extended Read
    mov ah, 0x42
    int 0x13

    pushf
    add sp, 16
    popf
    jc .error

    ; ===== MOSTRAR PROGRESO =====
    push ax
    push bx
    movzx eax, word [.sectors_this_block]
.print_plus:
    push ax
    mov al, '+'
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop ax
    dec ax
    jnz .print_plus
    pop bx
    pop ax
    ; ===========================

    ; Actualizar LBA
    movzx eax, word [.sectors_this_block]
    add ebp, eax
    adc esi, 0

    ; Actualizar buffer (sectores × 512)
    mov ax, [.sectors_this_block]
    shl ax, 9               ; × 512
    add di, ax
    jnc .no_wrap

    ; Ajustar ES
    mov bx, es
    add bx, 0x1000
    mov es, bx

.no_wrap:
    ; Restar sectores leídos del total
    mov ax, [.sectors_this_block]
    sub word [.total_sectors], ax
    mov cx, [.total_sectors]
    jnz .read_loop

    clc
    jmp .done

.error:
    stc

.done:
    popad
    ret

.total_sectors: dw 0
.sectors_this_block: dw 0
;*****************************************************************************
; //END: final función para leer sectores del disco.
; - leyendo múltiples sectores a la vez.
;*****************************************************************************

;*****************************************************************************
; read_sectors_to_high - Lee sectores a memoria alta (>1MB)
;*****************************************************************************
; Usa buffer intermedio en 0x10000 porque INT 13h no puede escribir >1MB
; Entrada:
;   EAX = LBA inicial
;   EDX = LBA high (normalmente 0)
;   CX  = Número de sectores
;   DL  = Drive (0x80)
;   EDI = Dirección destino en memoria alta (ej: 0x1000000)
; Salida:
;   CF = 0 si éxito, 1 si error
;*****************************************************************************
read_sectors_to_high_mem:
    pushad

    mov ebp, eax            ; EBP = LBA actual
    mov esi, edi            ; ESI = destino en memoria alta
    ; CX = sectores totales
    ; DL = drive

.loop:
    ; Calcular cuántos sectores leer (máximo 127)
    mov ax, cx
    cmp ax, 127
    jle .do_read
    mov ax, 127

.do_read:
    push cx                 ; Guardar sectores restantes
    mov cx, ax              ; CX = sectores este bloque
    push cx                 ; Guardar para la copia

    ; === LEER A BUFFER BAJO ===
    mov eax, ebp            ; LBA
    xor edx, edx
    mov dl, 0x80            ; Drive

    ; ES:DI = 0x1000:0000 = 0x10000
    mov bx, 0x1000
    mov es, bx
    xor di, di

    ; Leer sectores
    call read_sectors_lba_internal
    jc .error

    ; Mostrar "-" (leído a memoria baja)
    push ax
    push bx
    mov al, '-'
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    pop ax

    ; === COPIAR A MEMORIA ALTA ===
    pop cx                  ; Recuperar sectores leídos
    push cx

    ; Origen: 0x10000
    mov edi, BUFFER_LOW

    ; Destino: ESI (ya apunta a memoria alta)
    ; (no modificar ESI aún)

    ; Bytes a copiar: CX * 512
    movzx ecx, cx
    shl ecx, 9              ; × 512

    ; Configurar DS=ES=0 para direccionamiento unreal
    xor ax, ax
    mov ds, ax
    push ax
    pop es

.copy_loop:
    a32 mov eax, [edi]      ; Leer de buffer bajo
    a32 mov [esi], eax      ; Escribir a memoria alta
    add edi, 4
    add esi, 4
    sub ecx, 4
    jnz .copy_loop

    ; Mostrar "+" (copiado a memoria alta)
    push ax
    push bx
    mov al, '+'
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    pop ax

    ; Actualizar para siguiente bloque
    pop cx                  ; Sectores que acabamos de procesar
    pop bx                  ; Sectores restantes originales

    ; LBA += sectores procesados
    movzx eax, cx
    add ebp, eax

    ; Sectores restantes -= sectores procesados
    sub bx, cx
    mov cx, bx

    ; Continuar si quedan sectores
    test cx, cx
    jnz .loop

    ; === ÉXITO ===
    popad
    clc
    ret

.error:
    ; Limpiar pila
    pop cx
    pop cx
    popad
    stc
    ret

;*****************************************************************************
; read_sectors_lba_internal - Lee sectores (solo memoria <1MB)
;*****************************************************************************
; Entrada:
;   EAX = LBA
;   CX  = Sectores
;   DL  = Drive
;   ES:DI = Buffer (DEBE estar <1MB)
;*****************************************************************************
read_sectors_lba_internal:
    pushad

    mov ebp, eax            ; LBA actual
    mov bl, dl              ; Guardar drive

.read_loop:
    ; Preparar DAP
    push dword 0            ; LBA high
    push ebp                ; LBA low
    push es
    push di
    push word 1             ; 1 sector
    push word 0x10

    mov si, sp
    push ss
    pop ds

    mov ah, 0x42
    mov dl, bl
    int 0x13

    pushf
    add sp, 16
    popf
    jc .error

    ; Siguiente sector
    inc ebp
    add di, 512
    jnc .no_wrap

    mov ax, es
    add ax, 0x1000
    mov es, ax

.no_wrap:
    loop .read_loop

    popad
    clc
    ret

.error:
    popad
    stc
    ret
;*****************************************************************************
; //END: fin de la función.
;*****************************************************************************
