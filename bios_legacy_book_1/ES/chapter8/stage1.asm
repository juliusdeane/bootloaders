[BITS 16]
[ORG 0x7C00]

start:
    mov [boot_drive], dl  ; el disco de arranque.

    ; Inicializar serial: COM1
    call init_com1

    ; LEEMOS EL STAGE2 *ANTES* DE PASAR A MODO PROTEGIDO.
    mov eax, STAGE2_START_SECTOR  ; sector inicial.
    xor edx, edx                  ; sector inicial (parte alta)
    mov cx, STAGE2_SIZE_SECTORS   ; total de sectores a leer.
    mov dl, [boot_drive]          ; la unidad de disco de donde leer.
    mov edi, STAGE2_ADDRESS

    call read_sectors_lba

    ; Si error...
    jc error_lectura_disco

    ; Guardar el disco de arranque en DL antes de saltar.
    mov dl, [boot_drive]

    ; Saltamos a STAGE2.
    jmp STAGE2_ADDRESS


error_lectura_disco:
    mov si, msg_disk_error
    call debug_print_string16

    hlt
    jmp $

%include "globals.asm"

; Primeros pasos a tener estructura de disco dinámica.
%include "structure.asm"
; Rutina de identificar los bits de cada .asm
%include "serial16.asm"
%include "disk16.asm"

; DATOS:
msg_stage1_completed_ok:  db '[STAGE1] Completado OK!', 13, 10, 0
msg_disk_error:           db '[STAGE1] Error de disco.', 13, 10, 0

; PADDING + FIRMA.
times 510-($-$$) db 0
dw MBR_SIG
