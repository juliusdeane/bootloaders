boot_drive: db 0

DATA_SEG               equ 0x10
CODE_SEG               equ 0x08

TEMP_READ_OFFSET       equ 0x7E00
KERNEL_LOAD_ADDR       equ 0x1000000  ; 16MB - zona segura
READ_START_SECTOR      equ 3
TOTAL_SECTORS_TO_READ  equ 10
TOTAL_SECTORS_SIZE     equ 5120        ; 10 x 512

SECTORS_TO_READ        equ 29221       ; Total de sectores:
; -rw------- 1 root root 14961032 sep 29 10:14 /boot/vmlinuz-6.8.0-86-generic

SECTORS_PER_CALL        equ 16          ; Leer de a 18 sectores (8KB)
START_LBA               equ 3           ; Sector inicial

pm_stack_top            equ 0x9FC00
;*****************************************************************************
; Mensajes de DEBUG genéricos
; - para poder poner debug visual.
;*****************************************************************************
msg_0: db '[0]', 13, 10, 0
msg_1: db '[1]', 13, 10, 0
msg_2: db '[2]', 13, 10, 0
msg_3: db '[3]', 13, 10, 0
msg_4: db '[4]', 13, 10, 0
; Definimos solamente cinco, para ahorrar bytes.
; msg_5: db '[5]', 13, 10, 0
; msg_6: db '[6]', 13, 10, 0
; msg_7: db '[7]', 13, 10, 0
; msg_8: db '[8]', 13, 10, 0
; msg_9: db '[9]', 13, 10, 0
