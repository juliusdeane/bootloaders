//=============================================================================
// idt64.c - Inicialización de la IDT en C
//=============================================================================

#include <stdint.h>

// Estructura de una entrada IDT
typedef struct {
    uint16_t offset_low;    // Offset bits 0-15
    uint16_t selector;      // Selector de código
    uint8_t  ist;           // Interrupt Stack Table
    uint8_t  type_attr;     // Type y atributos
    uint16_t offset_mid;    // Offset bits 16-31
    uint32_t offset_high;   // Offset bits 32-63
    uint32_t zero;          // Reservado
} __attribute__((packed)) idt_entry_t;

// Estructura del puntero IDT
typedef struct {
    uint16_t limit;
    uint64_t base;
} __attribute__((packed)) idt_ptr_t;

// Tabla IDT (256 entradas)
idt_entry_t idt[256] __attribute__((aligned(16)));
idt_ptr_t idt64_ptr;

// Declarar ISRs externos (definidos en idt64_handlers.asm)
extern void isr0(void);
extern void isr1(void);
extern void isr2(void);
extern void isr3(void);
extern void isr4(void);
extern void isr5(void);
extern void isr6(void);
extern void isr7(void);
extern void isr8(void);
extern void isr9(void);
extern void isr10(void);
extern void isr11(void);
extern void isr12(void);
extern void isr13(void);
extern void isr14(void);
extern void isr15(void);
extern void isr16(void);
extern void isr17(void);
extern void isr18(void);
extern void isr19(void);
extern void isr20(void);
extern void isr21(void);
extern void isr22(void);
extern void isr23(void);
extern void isr24(void);
extern void isr25(void);
extern void isr26(void);
extern void isr27(void);
extern void isr28(void);
extern void isr29(void);
extern void isr30(void);
extern void isr31(void);

extern void irq0(void);
extern void irq1(void);
extern void irq2(void);
extern void irq3(void);
extern void irq4(void);
extern void irq5(void);
extern void irq6(void);
extern void irq7(void);
extern void irq8(void);
extern void irq9(void);
extern void irq10(void);
extern void irq11(void);
extern void irq12(void);
extern void irq13(void);
extern void irq14(void);
extern void irq15(void);

extern void isr128(void);  // Syscall

// Función para configurar una entrada IDT
static void idt_set_gate(uint8_t num, uint64_t handler, uint16_t selector, uint8_t flags) {
    idt[num].offset_low = handler & 0xFFFF;
    idt[num].selector = selector;
    idt[num].ist = 0;
    idt[num].type_attr = flags;
    idt[num].offset_mid = (handler >> 16) & 0xFFFF;
    idt[num].offset_high = (handler >> 32) & 0xFFFFFFFF;
    idt[num].zero = 0;
}

// Inicializar la IDT
void idt_init(void) {
    // Limpiar la IDT
    for (int i = 0; i < 256; i++) {
        idt[i].offset_low = 0;
        idt[i].selector = 0;
        idt[i].ist = 0;
        idt[i].type_attr = 0;
        idt[i].offset_mid = 0;
        idt[i].offset_high = 0;
        idt[i].zero = 0;
    }

    // Selector de código del kernel = 0x08
    // Flags: P=1, DPL=00, Type=1110 (Interrupt Gate) = 0x8E
    uint16_t kernel_cs = 0x08;
    uint8_t kernel_gate = 0x8E;

    // Instalar ISRs para excepciones (0-31)
    idt_set_gate(0, (uint64_t)isr0, kernel_cs, kernel_gate);
    idt_set_gate(1, (uint64_t)isr1, kernel_cs, kernel_gate);
    idt_set_gate(2, (uint64_t)isr2, kernel_cs, kernel_gate);
    idt_set_gate(3, (uint64_t)isr3, kernel_cs, kernel_gate);
    idt_set_gate(4, (uint64_t)isr4, kernel_cs, kernel_gate);
    idt_set_gate(5, (uint64_t)isr5, kernel_cs, kernel_gate);
    idt_set_gate(6, (uint64_t)isr6, kernel_cs, kernel_gate);
    idt_set_gate(7, (uint64_t)isr7, kernel_cs, kernel_gate);
    idt_set_gate(8, (uint64_t)isr8, kernel_cs, kernel_gate);
    idt_set_gate(9, (uint64_t)isr9, kernel_cs, kernel_gate);
    idt_set_gate(10, (uint64_t)isr10, kernel_cs, kernel_gate);
    idt_set_gate(11, (uint64_t)isr11, kernel_cs, kernel_gate);
    idt_set_gate(12, (uint64_t)isr12, kernel_cs, kernel_gate);
    idt_set_gate(13, (uint64_t)isr13, kernel_cs, kernel_gate);
    idt_set_gate(14, (uint64_t)isr14, kernel_cs, kernel_gate);
    idt_set_gate(15, (uint64_t)isr15, kernel_cs, kernel_gate);
    idt_set_gate(16, (uint64_t)isr16, kernel_cs, kernel_gate);
    idt_set_gate(17, (uint64_t)isr17, kernel_cs, kernel_gate);
    idt_set_gate(18, (uint64_t)isr18, kernel_cs, kernel_gate);
    idt_set_gate(19, (uint64_t)isr19, kernel_cs, kernel_gate);
    idt_set_gate(20, (uint64_t)isr20, kernel_cs, kernel_gate);
    idt_set_gate(21, (uint64_t)isr21, kernel_cs, kernel_gate);
    idt_set_gate(22, (uint64_t)isr22, kernel_cs, kernel_gate);
    idt_set_gate(23, (uint64_t)isr23, kernel_cs, kernel_gate);
    idt_set_gate(24, (uint64_t)isr24, kernel_cs, kernel_gate);
    idt_set_gate(25, (uint64_t)isr25, kernel_cs, kernel_gate);
    idt_set_gate(26, (uint64_t)isr26, kernel_cs, kernel_gate);
    idt_set_gate(27, (uint64_t)isr27, kernel_cs, kernel_gate);
    idt_set_gate(28, (uint64_t)isr28, kernel_cs, kernel_gate);
    idt_set_gate(29, (uint64_t)isr29, kernel_cs, kernel_gate);
    idt_set_gate(30, (uint64_t)isr30, kernel_cs, kernel_gate);
    idt_set_gate(31, (uint64_t)isr31, kernel_cs, kernel_gate);

    // Instalar IRQs (32-47)
    idt_set_gate(32, (uint64_t)irq0, kernel_cs, kernel_gate);
    idt_set_gate(33, (uint64_t)irq1, kernel_cs, kernel_gate);
    idt_set_gate(34, (uint64_t)irq2, kernel_cs, kernel_gate);
    idt_set_gate(35, (uint64_t)irq3, kernel_cs, kernel_gate);
    idt_set_gate(36, (uint64_t)irq4, kernel_cs, kernel_gate);
    idt_set_gate(37, (uint64_t)irq5, kernel_cs, kernel_gate);
    idt_set_gate(38, (uint64_t)irq6, kernel_cs, kernel_gate);
    idt_set_gate(39, (uint64_t)irq7, kernel_cs, kernel_gate);
    idt_set_gate(40, (uint64_t)irq8, kernel_cs, kernel_gate);
    idt_set_gate(41, (uint64_t)irq9, kernel_cs, kernel_gate);
    idt_set_gate(42, (uint64_t)irq10, kernel_cs, kernel_gate);
    idt_set_gate(43, (uint64_t)irq11, kernel_cs, kernel_gate);
    idt_set_gate(44, (uint64_t)irq12, kernel_cs, kernel_gate);
    idt_set_gate(45, (uint64_t)irq13, kernel_cs, kernel_gate);
    idt_set_gate(46, (uint64_t)irq14, kernel_cs, kernel_gate);
    idt_set_gate(47, (uint64_t)irq15, kernel_cs, kernel_gate);

    // Instalar syscall (128 / 0x80) - Accesible desde Ring 3
    // Flags: P=1, DPL=11, Type=1110 = 0xEE
    idt_set_gate(128, (uint64_t)isr128, kernel_cs, 0xEE);

    // Configurar el puntero IDT
    idt64_ptr.limit = sizeof(idt) - 1;
    idt64_ptr.base = (uint64_t)&idt;

    // Cargar la IDT
    __asm__ volatile("lidt (%0)" : : "r"(&idt64_ptr));
}
