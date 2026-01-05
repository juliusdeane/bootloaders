;*****************************************************************************
; Definiciones ATA que vamos a necesitar.
;*****************************************************************************
; Puertos del controlador ATA primario
ATA_PRIMARY_DATA        equ 0x1f0    ; Puerto de datos (16 bits)
ATA_PRIMARY_SECCOUNT    equ 0x1f2
ATA_PRIMARY_ERROR       equ 0x1f1    ; Registro de error (lectura)
ATA_PRIMARY_LBA_LOW     equ 0x1f3
ATA_PRIMARY_LBA_MID     equ 0x1f4
ATA_PRIMARY_LBA_HIGH    equ 0x1f5
ATA_PRIMARY_DRIVE       equ 0x1f6
ATA_PRIMARY_STATUS      equ 0x1f7
ATA_PRIMARY_COMMAND     equ 0x1f7

; Comandos ATA
ATA_CMD_READ_SECTORS    equ 0x20
ATA_SR_BSY              equ 0x80
ATA_SR_DRDY             equ 0x40
ATA_SR_DRQ              equ 0x08
ATA_SR_ERR              equ 0x01
ATA_CMD_IDENTIFY        equ 0xec     ; Identificar dispositivo

; Bits de estado
ATA_SR_BSY              equ 0x80     ; Busy
ATA_SR_DRDY             equ 0x40     ; Drive Ready
ATA_SR_DRQ              equ 0x08     ; Data Request
ATA_SR_ERR              equ 0x01     ; Error
