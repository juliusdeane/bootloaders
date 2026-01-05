;*****************************************************************************
; IDT64_HANDLERS.ASM - Manejadores de Interrupciones
;*****************************************************************************

[BITS 64]

; Exportar todos los símbolos
global isr0, isr1, isr2, isr3, isr4, isr5, isr6, isr7
global isr8, isr9, isr10, isr11, isr12, isr13, isr14, isr15
global isr16, isr17, isr18, isr19, isr20, isr21, isr22, isr23
global isr24, isr25, isr26, isr27, isr28, isr29, isr30, isr31
global irq0, irq1, irq2, irq3, irq4, irq5, irq6, irq7
global irq8, irq9, irq10, irq11, irq12, irq13, irq14, irq15
global isr128

; Funciones del kernel
extern isr_handler
extern syscall_dispatcher

section .text

;*****************************************************************************
; Macros para ISRs
;*****************************************************************************
%macro ISR_NOERRCODE 1
isr%1:
    push qword 0           ; Dummy error code
    push qword %1          ; Interrupt number
    jmp isr_common_stub
%endmacro

%macro ISR_ERRCODE 1
isr%1:
    push qword %1          ; Interrupt number (error code ya está)
    jmp isr_common_stub
%endmacro

%macro IRQ 2
irq%1:
    push qword 0
    push qword %2
    jmp isr_common_stub
%endmacro

;*****************************************************************************
; ISRs para excepciones (0-31)
;*****************************************************************************
ISR_NOERRCODE 0     ; Division Error
ISR_NOERRCODE 1     ; Debug
ISR_NOERRCODE 2     ; NMI
ISR_NOERRCODE 3     ; Breakpoint
ISR_NOERRCODE 4     ; Overflow
ISR_NOERRCODE 5     ; Bound Range Exceeded
ISR_NOERRCODE 6     ; Invalid Opcode
ISR_NOERRCODE 7     ; Device Not Available
ISR_ERRCODE   8     ; Double Fault
ISR_NOERRCODE 9     ; Coprocessor Segment Overrun
ISR_ERRCODE   10    ; Invalid TSS
ISR_ERRCODE   11    ; Segment Not Present
ISR_ERRCODE   12    ; Stack Segment Fault
ISR_ERRCODE   13    ; General Protection Fault
ISR_ERRCODE   14    ; Page Fault
ISR_NOERRCODE 15    ; Reserved
ISR_NOERRCODE 16    ; x87 FPU Error
ISR_ERRCODE   17    ; Alignment Check
ISR_NOERRCODE 18    ; Machine Check
ISR_NOERRCODE 19    ; SIMD Floating-Point Exception
ISR_NOERRCODE 20    ; Virtualization Exception
ISR_NOERRCODE 21    ; Reserved
ISR_NOERRCODE 22    ; Reserved
ISR_NOERRCODE 23    ; Reserved
ISR_NOERRCODE 24    ; Reserved
ISR_NOERRCODE 25    ; Reserved
ISR_NOERRCODE 26    ; Reserved
ISR_NOERRCODE 27    ; Reserved
ISR_NOERRCODE 28    ; Reserved
ISR_NOERRCODE 29    ; Reserved
ISR_NOERRCODE 30    ; Reserved
ISR_NOERRCODE 31    ; Reserved

;*****************************************************************************
; IRQs (32-47)
;*****************************************************************************
IRQ 0, 32
IRQ 1, 33
IRQ 2, 34
IRQ 3, 35
IRQ 4, 36
IRQ 5, 37
IRQ 6, 38
IRQ 7, 39
IRQ 8, 40
IRQ 9, 41
IRQ 10, 42
IRQ 11, 43
IRQ 12, 44
IRQ 13, 45
IRQ 14, 46
IRQ 15, 47

;*****************************************************************************
; Syscall (128 / 0x80)
;*****************************************************************************
isr128:
    ; Guardar registros
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Parámetros en registros:
    ; rax = syscall number
    ; Obtener valores originales de la pila
    mov rdi, rax            ; arg0: syscall number
    mov rsi, [rsp + 8*7]    ; arg1: rdi original
    mov rdx, [rsp + 8*6]    ; arg2: rsi original
    mov rcx, [rsp + 8*5]    ; arg3: rdx original
    mov r8,  [rsp + 8*2]    ; arg4: r10 original
    mov r9,  [rsp + 8*9]    ; arg5: r8 original

    ; Llamar dispatcher
    call syscall_dispatcher

    ; Restaurar registros (excepto rax que tiene el retorno)
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    add rsp, 8      ; Skip rax

    iretq

;*****************************************************************************
; Stub común para interrupciones
;*****************************************************************************
isr_common_stub:
    ; Guardar todos los registros
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Pasar stack frame como argumento
    mov rdi, rsp
    call isr_handler

    ; Restaurar registros
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ; Limpiar error code y vector number
    add rsp, 16

    iretq
