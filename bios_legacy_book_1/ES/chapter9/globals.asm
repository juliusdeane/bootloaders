boot_drive:                db 0

STAGE2_ADDRESS             equ 0x8000
STAGE3_ADDRESS             equ 0x100000
KERNEL_ADDRESS             equ 0x300000

VIDEO_MODE                 equ 0x0013
FRAMEBUFFER_ADDR16         equ 0xA000
FRAMEBUFFER_ADDR32         equ 0xA000

DATA_SEG                   equ 0x10
CODE_SEG                   equ 0x08

; DEFINO CONSTANTES GENERALES:
; - evito ir cambiando valores uno a uno.
MBR_SIG                    equ 0xaa55
VBR_SIG_A                  equ 0x41414141
VBR_SIG_B                  equ 0x42424242
VBR_SIG_C                  equ 0x43434343
VBR_SIG_D                  equ 0x44444444
;*****************************************************************************
; Mensajes de DEBUG genéricos
; - para poder poner debug visual.
;*****************************************************************************
msg_0: db '[0]', 13, 10, 0
msg_1: db '[1]', 13, 10, 0
msg_2: db '[2]', 13, 10, 0
msg_3: db '[3]', 13, 10, 0
msg_4: db '[4]', 13, 10, 0
msg_5: db '[5]', 13, 10, 0
msg_6: db '[6]', 13, 10, 0
msg_7: db '[7]', 13, 10, 0
msg_8: db '[8]', 13, 10, 0
msg_9: db '[9]', 13, 10, 0
