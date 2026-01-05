;*****************************************************************************
; GDT64: para Modo Largo con ring3
;*****************************************************************************
; En modo largo, los descriptores de segmento siguen siendo necesarios
; principalmente para definir los niveles de privilegio (DPL)
;*****************************************************************************
gdt64:
    ; Descriptor 0: Null descriptor (obligatorio)
    dq 0

    ; Descriptor 1: Código Ring 0 (kernel)
.code: equ $ - gdt64
    ; Base=0, Limit=0, P=1, DPL=00, S=1, Type=1010 (Execute/Read)
    ; L=1 (64-bit), D=0
    dq 0x00209A0000000000

    ; Descriptor 2: Datos Ring 0 (kernel)
.data: equ $ - gdt64
    ; Base=0, Limit=0, P=1, DPL=00, S=1, Type=0010 (Read/Write)
    dq 0x0000920000000000

    ; Descriptor 3: Código Ring 3 (usuario)
.user_code: equ $ - gdt64
    ; Base=0, Limit=0, P=1, DPL=11, S=1, Type=1010 (Execute/Read)
    ; L=1 (64-bit), D=0
    dq 0x0020FA0000000000

    ; Descriptor 4: Datos Ring 3 (usuario)
.user_data: equ $ - gdt64
    ; Base=0, Limit=0, P=1, DPL=11, S=1, Type=0010 (Read/Write)
    dq 0x0000F20000000000

gdt64_ptr:
    dw $ - gdt64 - 1    ; Límite
    dq gdt64            ; Base (64-bit)

;*****************************************************************************
; Constantes útiles para usar en código
;*****************************************************************************
; Para usar en código: mov ax, KERNEL_DATA_SEG
KERNEL_CODE_SEG equ gdt64.code
KERNEL_DATA_SEG equ gdt64.data
USER_CODE_SEG   equ gdt64.user_code | 3  ; OR 3 para indicar RPL=3
USER_DATA_SEG   equ gdt64.user_data | 3

;INICIO GDT ORIGINAL:
;gdt64:
;    dq 0                    ; null descriptor
;.code: equ $ - gdt64
;    dq 0x00209A0000000000   ; código 64-bit
;.data: equ $ - gdt64
;    dq 0x0000920000000000   ; datos 64-bit
;
;gdt64_ptr:
;    dw $ - gdt64 - 1
;    dd gdt64
;FIN GDT ORIGINAL.
