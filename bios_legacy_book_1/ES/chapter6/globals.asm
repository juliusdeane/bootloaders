boot_drive:                db 0

STAGE2_ADDRESS             equ 0x8000

DATA_SEG                   equ 0x10
CODE_SEG                   equ 0x08

; DEFINO CONSTANTES GENERALES:
; - evito ir cambiando valores uno a uno.
MBR_SIG                    equ 0xaa55
VBR_SIG_A                  equ 0x41414141
VBR_SIG_B                  equ 0x42424242
VBR_SIG_C                  equ 0x43434343

KERNEL_LOAD_ADDRESS        equ 0x01000000
KERNEL_INITIAL_SECTOR      equ 17
KERNEL_LOAD_SECTORS        equ 29620
KERNEL_SETUP_ADDRESS       equ 0x90000
; KERNEL_PAYLOAD_ADDRESS     equ 0x100000
; - si seguimos lo que pide alineación.
KERNEL_PAYLOAD_ADDRESS     equ 0x200000

KERNEL_HDRS_SIG            equ 0x53726448

INITRD_DISK_START_OFFSET   equ 14969760
INITRD_INITIAL_SECTOR      equ 29637
;INITRD_LOAD_ADDRESS        equ 0x3000000
INITRD_LOAD_ADDRESS        equ 0x6000000
INITRD_MAX_LENGTH          equ 1100000
INITRD_MAX_SECTORS         equ 2149
KERNEL_INITRD_PTR          equ 0x90218  ; setup base + 0x218
KERNEL_INITRD_BYTES        equ 0x9021c  ; setup base + 0x21c

KERNEL_BOOTLOADER_TYPE     equ 0x90210  ; setup base + 0x210
KERNEL_LOADFLAGS           equ 0x90211  ; setup base + 0x211
KERNEL_HEAP_END_PTR        equ 0x90224  ; setup base + 0x224

KERNEL_CMDLINE_ADDRESS     equ 0x9e000
KERNEL_SETUP_CMDLINE_PTR   equ 0x90228  ; setup base + 0x228

KERNEL_UNKNOWN_BOOTLOADER  equ 0xff
KERNEL_SET_LOADFLAGS       equ 0x81
KERNEL_SET_HEAP_END        equ 0x0009de00
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
