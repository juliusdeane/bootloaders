;*****************************************************************************
; IDT64_DATA.ASM - Solo las estructuras de datos de la IDT
;*****************************************************************************
; Este archivo se compila como objeto (.o) y se enlaza con el kernel
; Contiene SOLO las estructuras de datos, no el código de los handlers
;*****************************************************************************

[BITS 64]

; Declarar los handlers como externos (se definirán en otro archivo)
extern isr_divide_error
extern isr_debug
extern isr_nmi
extern isr_breakpoint
extern isr_overflow
extern isr_bound_range
extern isr_invalid_opcode
extern isr_device_not_avail
extern isr_double_fault
extern isr_coproc_segment
extern isr_invalid_tss
extern isr_segment_not_present
extern isr_stack_segment
extern isr_general_protection
extern isr_page_fault
extern isr_reserved
extern isr_fpu_error
extern isr_alignment_check
extern isr_machine_check
extern isr_simd_exception
extern isr_virtualization
extern isr_hardware_irq
extern syscall_handler

; Selector de código del kernel (desde GDT)
%define KERNEL_CODE_SEG 0x08

;*****************************************************************************
; Macro para crear entradas en la IDT
;*****************************************************************************
%macro IDT_ENTRY 1
    dw (%1 & 0xFFFF)              ; Offset bits 0-15
    dw KERNEL_CODE_SEG             ; Selector de segmento de código
    db 0                           ; IST = 0
    db 10001110b                   ; P=1, DPL=00, Type=1110 (Interrupt Gate)
    dw ((%1 >> 16) & 0xFFFF)      ; Offset bits 16-31
    dd (%1 >> 32)                  ; Offset bits 32-63
    dd 0                           ; Reserved
%endmacro

%macro IDT_ENTRY_USER 1
    dw (%1 & 0xFFFF)              ; Offset bits 0-15
    dw KERNEL_CODE_SEG             ; Selector de segmento de código
    db 0                           ; IST = 0
    db 11101110b                   ; P=1, DPL=11 (ring 3), Type=1110
    dw ((%1 >> 16) & 0xFFFF)      ; Offset bits 16-31
    dd (%1 >> 32)                  ; Offset bits 32-63
    dd 0                           ; Reserved
%endmacro

;*****************************************************************************
; Tabla IDT - SOLO DATOS
;*****************************************************************************
section .data
global idt64_start
global idt64_ptr

idt64_start:
    ; Vector 0-31: Excepciones del CPU
    IDT_ENTRY isr_divide_error        ; 0
    IDT_ENTRY isr_debug               ; 1
    IDT_ENTRY isr_nmi                 ; 2
    IDT_ENTRY isr_breakpoint          ; 3
    IDT_ENTRY isr_overflow            ; 4
    IDT_ENTRY isr_bound_range         ; 5
    IDT_ENTRY isr_invalid_opcode      ; 6
    IDT_ENTRY isr_device_not_avail    ; 7
    IDT_ENTRY isr_double_fault        ; 8
    IDT_ENTRY isr_coproc_segment      ; 9
    IDT_ENTRY isr_invalid_tss         ; 10
    IDT_ENTRY isr_segment_not_present ; 11
    IDT_ENTRY isr_stack_segment       ; 12
    IDT_ENTRY isr_general_protection  ; 13
    IDT_ENTRY isr_page_fault          ; 14
    IDT_ENTRY isr_reserved            ; 15
    IDT_ENTRY isr_fpu_error           ; 16
    IDT_ENTRY isr_alignment_check     ; 17
    IDT_ENTRY isr_machine_check       ; 18
    IDT_ENTRY isr_simd_exception      ; 19
    IDT_ENTRY isr_virtualization      ; 20

    ; 21-31: Reservadas
    %rep 11
        IDT_ENTRY isr_reserved
    %endrep

    ; 32-47: IRQs del hardware
    %rep 16
        IDT_ENTRY isr_hardware_irq
    %endrep

    ; 48-127: Disponibles
    %rep 80
        IDT_ENTRY isr_reserved
    %endrep

    ; 128 (0x80): Syscall desde ring 3
    IDT_ENTRY_USER syscall_handler

    ; 129-255: Disponibles
    %rep 127
        IDT_ENTRY isr_reserved
    %endrep

idt64_end:

idt64_ptr:
    dw idt64_end - idt64_start - 1  ; Límite
    dq idt64_start                   ; Base
