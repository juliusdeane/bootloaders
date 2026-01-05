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