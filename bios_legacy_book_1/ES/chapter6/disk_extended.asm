BUFFER_LOW equ 0x10000      ; Buffer temporal (64KB)

;*****************************************************************************
; read_sectors_to_high_mem - Lee sectores a memoria alta (>1MB)
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
; //END: read_sectors_to_high - Lee sectores a memoria alta (>1MB)
;*****************************************************************************

;*****************************************************************************
; read_sectors_to_high_mem_ng - Lee sectores a memoria alta (>1MB)
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
;   EAX = Bytes totales leídos
;*****************************************************************************
; Prototipo: read_sectors_to_high_mem(LBA: EAX, Destino: EDI, Sectores: CX, Drive: DL)
read_sectors_to_high_mem_ng:
    pushad
    xor ebx, ebx            ; EBX = contador de bytes (inicialmente 0)
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

    ; Calcular bytes leídos en este bloque y acumular en EBX
    movzx eax, cx
    shl eax, 9              ; × 512 para obtener bytes
    add ebx, eax            ; Acumular en EBX

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
    ; Mover el total de bytes de EBX a EAX para retornarlo
    mov [esp + 28], ebx     ; Sobrescribir EAX guardado en pushad (offset 28)
    popad
    clc
    ret

.error:
    ; Limpiar pila
    pop cx
    pop cx
    ; En caso de error, retornar 0 bytes
    mov [esp + 28], dword 0 ; Sobrescribir EAX guardado con 0
    popad
    stc
    ret
;*****************************************************************************
; //END: read_sectors_to_high_mem_ng - Lee sectores a memoria alta (>1MB)
;*****************************************************************************

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
;*****************************************************************************
; read_until_signature - Lee bytes hasta encontrar firma (VERSIÓN COMPACTA)
;*****************************************************************************
; Firma: 00 00 00 00 00 00 00 00 AD DE EF BE
; Entrada:
;   EAX = Offset inicial en bytes
;   DL  = Drive (0x80)
;   EDI = Dirección destino en memoria alta
;   ECX = Tamaño máximo (protección)
; Salida:
;   CF = 0 si éxito, EAX = bytes leídos
;*****************************************************************************
read_until_signature:
    pushad
    mov [.start_off], eax
    mov [.dest], edi
    mov [.drv], dl
    mov [.max], ecx
    xor eax, eax
    mov [.total], eax

    ; LBA inicial y offset en sector
    mov eax, [.start_off]
    xor edx, edx
    mov ebx, 512
    div ebx
    mov [.lba], eax
    mov [.off], edx

.chunk:
    ; Leer 16 sectores (8KB)
    mov eax, [.lba]
    xor edx, edx
    mov cx, 16
    mov dl, [.drv]
    mov edi, BUFFER_LOW
    call read_sectors_to_high_mem
    jc .err

    ; Buscar firma
    mov esi, BUFFER_LOW
    add esi, [.off]
    mov ecx, 8192
    sub ecx, [.off]

    ; Limitar por max_bytes
    mov eax, [.total]
    add eax, ecx
    cmp eax, [.max]
    jbe .srch
    mov ecx, [.max]
    sub ecx, [.total]

.srch:
    mov ebx, ecx
.slp:
    cmp ebx, 12
    jb .nf

    ; Verificar firma
    a32 mov eax, [esi]
    test eax, eax
    jnz .nx
    a32 mov eax, [esi+4]
    test eax, eax
    jnz .nx
    a32 mov eax, [esi+8]
    cmp eax, 0xBEEFDEAD
    je .fnd

.nx:
    inc esi
    dec ebx
    jmp .slp

.nf:
    ; No encontrada, copiar bloque
    mov eax, [.total]
    add eax, ecx
    cmp eax, [.max]
    ja .err

    mov esi, BUFFER_LOW
    add esi, [.off]
    mov edi, [.dest]
    add edi, [.total]

    ; Copiar
    push ecx
.cp:
    test ecx, ecx
    jz .cpd
    a32 mov al, [esi]
    a32 mov [edi], al
    inc esi
    inc edi
    dec ecx
    jmp .cp
.cpd:
    pop ecx
    add [.total], ecx
    add dword [.lba], 16
    mov dword [.off], 0
    jmp .chunk

.fnd:
    ; Copiar hasta firma
    mov eax, esi
    sub eax, BUFFER_LOW
    sub eax, [.off]
    mov ecx, eax

    mov esi, BUFFER_LOW
    add esi, [.off]
    mov edi, [.dest]
    add edi, [.total]

.fcp:
    test ecx, ecx
    jz .ok
    a32 mov al, [esi]
    a32 mov [edi], al
    inc esi
    inc edi
    inc dword [.total]
    dec ecx
    jmp .fcp

.ok:
    mov eax, [.total]
    mov [esp+28], eax
    popad
    clc
    ret

.err:
    popad
    stc
    ret

.start_off: dd 0
.dest:      dd 0
.drv:       db 0
.lba:       dd 0
.off:       dd 0
.total:     dd 0
.max:       dd 0
