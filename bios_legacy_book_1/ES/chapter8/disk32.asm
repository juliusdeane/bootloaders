[BITS 32]

%include "ata.asm"

;*****************************************************************************
; read_sectors_pm
; - Leer N sectores del disco en modo protegido (32 bits)
;
; Parámetros:
;   EAX = LBA (sector inicial, 28 bits útiles)
;   ECX = número de sectores a leer (máximo 256, 0 = 256)
;   EDX = número de disco:
;         - 0x80 = primer disco duro (master en primary)
;         - 0x81 = segundo disco duro (slave en primary)
;   EDI = dirección de memoria destino (dirección lineal, puede ser > 1 MB)
;
; Retorno:
;   CF = 0 si OK, CF = 1 si error
;   EAX = número de sectores leídos exitosamente
;
; Preserva: EBX, ESI
;*****************************************************************************
read_sectors_pm:
    push ebx
    push esi
    push ebp

    mov ebp, ecx                ; Guardar número total de sectores
    xor esi, esi                ; Contador de sectores leídos

    ; Convertir número de disco (0x80/0x81) a bit de drive
    ; 0x80 (master) -> bit 4 = 0
    ; 0x81 (slave)  -> bit 4 = 1
    mov ebx, edx
    and ebx, 0x01               ; Extraer bit 0 (master=0, slave=1)
    shl ebx, 4                  ; Mover a bit 4
    or  ebx, 0xE0               ; Agregar bits: LBA mode (bit 6) + bits 7,5 = 1
                                ; Resultado: 0xE0 = master, 0xF0 = slave

.read_loop:
    cmp esi, ebp                ; ¿Ya leímos todos los sectores?
    jge .success

    ; Esperar a que el disco esté listo
    call ata_wait_ready
    jc .error_not_ready

    ; Calcular cuántos sectores leer en este lote (máximo 256 por comando)
    mov ecx, ebp
    sub ecx, esi                ; Sectores restantes
    cmp ecx, 256
    jle .seccount_ok
    mov ecx, 256                ; Máximo 256 sectores por vez
.seccount_ok:

    ; Configurar parámetros para leer
    push eax                    ; Guardar LBA
    push ecx                    ; Guardar sector count

    ; Enviar número de sectores (0 = 256)
    mov al, cl
    mov dx, ATA_PRIMARY_SECCOUNT
    out dx, al

    ; Enviar LBA (28 bits)
    pop ecx                     ; Recuperar count
    pop eax                     ; Recuperar LBA
    push eax
    push ecx

    mov dx, ATA_PRIMARY_LBA_LOW
    out dx, al                  ; LBA bits 0-7

    shr eax, 8
    mov dx, ATA_PRIMARY_LBA_MID
    out dx, al                  ; LBA bits 8-15

    shr eax, 8
    mov dx, ATA_PRIMARY_LBA_HIGH
    out dx, al                  ; LBA bits 16-23

    shr eax, 8
    and al, 0x0F                ; Solo 4 bits de LBA (24-27)
    or  al, bl                  ; Agregar drive select + LBA mode
    mov dx, ATA_PRIMARY_DRIVE
    out dx, al

    ; Enviar comando de lectura
    mov al, ATA_CMD_READ_SECTORS
    mov dx, ATA_PRIMARY_COMMAND
    out dx, al

    ; Leer los sectores
    pop ecx                     ; Recuperar número de sectores
    pop eax                     ; Recuperar LBA

.read_sector_loop:
    push ecx
    push eax

    ; Esperar a que el disco tenga datos listos
    call ata_wait_data
    jc .error_no_data

    ; Mostrar "." por sector (29620 puntos si ok).
    mov al, '.'
    call putc_serial

    ; Leer 512 bytes (256 words de 16 bits)
    mov ecx, 256
    mov dx, ATA_PRIMARY_DATA

.read_word_loop:
    in ax, dx                   ; Leer word (16 bits)
    mov [edi], ax
    add edi, 2
    loop .read_word_loop

    pop eax
    pop ecx

    inc eax                     ; Siguiente LBA
    inc esi                     ; Incrementar contador de sectores leídos
    dec ecx
    jnz .read_sector_loop

    jmp .read_loop

.error_no_data:
    pop eax
    pop ecx
    mov edx, 0x02               ; Error: disco no tiene datos listos
    jmp .error_common

.error_not_ready:
    mov edx, 0x01               ; Error: disco no está listo
    jmp .error_common

.error_common:
    mov eax, esi                ; Retornar sectores leídos
    stc                         ; CF = 1 (error)
    pop ebp
    pop esi
    pop ebx
    ret

.success:
    mov eax, esi                ; Retornar sectores leídos
    xor edx, edx                ; EDX = 0 (sin error)
    clc                         ; CF = 0 (éxito)
    pop ebp
    pop esi
    pop ebx
    ret

;*****************************************************************************
; ata_wait_ready
; - Esperar a que el disco esté listo (BSY=0, DRDY=1)
;
; Retorno:
;   CF = 0 si OK, CF = 1 si timeout/error
;*****************************************************************************
ata_wait_ready:
    push eax
    push ecx
    push edx

    mov ecx, 0x20000            ; Timeout counter (ajustable)

.wait_loop:
    mov dx, ATA_PRIMARY_STATUS
    in al, dx

    test al, ATA_SR_BSY         ; ¿Busy?
    jz .check_ready             ; No busy, verificar ready

    dec ecx
    jnz .wait_loop

    ; Timeout
    stc                         ; CF = 1
    pop edx
    pop ecx
    pop eax
    ret

.check_ready:
    test al, ATA_SR_DRDY        ; ¿Drive ready?
    jnz .ready

    dec ecx
    jnz .wait_loop

    ; Timeout
    stc
    pop edx
    pop ecx
    pop eax
    ret

.ready:
    clc                         ; CF = 0
    pop edx
    pop ecx
    pop eax
    ret

;*****************************************************************************
; ata_wait_data
; - Esperar a que el disco tenga datos listos (DRQ=1)
;
; Retorno:
;   CF = 0 si OK, CF = 1 si timeout/error
;*****************************************************************************
ata_wait_data:
    push eax
    push ecx
    push edx

    mov ecx, 0x20000            ; Timeout counter

.wait_loop:
    mov dx, ATA_PRIMARY_STATUS
    in al, dx

    test al, ATA_SR_BSY         ; ¿Todavía busy?
    jnz .continue               ; Sí, seguir esperando

    test al, ATA_SR_DRQ         ; ¿Data ready?
    jnz .data_ready

    test al, ATA_SR_ERR         ; ¿Error?
    jnz .error

.continue:
    dec ecx
    jnz .wait_loop

    ; Timeout
    stc
    pop edx
    pop ecx
    pop eax
    ret

.error:
    stc
    pop edx
    pop ecx
    pop eax
    ret

.data_ready:
    clc
    pop edx
    pop ecx
    pop eax
    ret

;*****************************************************************************
; Función auxiliar para imprimir mensaje de error de disco
;*****************************************************************************
disk_error_pm32:
    ; Leer registro de error
    mov dx, ATA_PRIMARY_ERROR
    in al, dx

    ; Aquí podrías llamar a una función para imprimir el código de error
    ; por ahora solo retornamos
    ret
