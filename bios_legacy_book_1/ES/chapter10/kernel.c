#include <stdint.h>


// Puertos del serial COM1
#define COM1 0x3F8

// Números de syscall
#define SYS_WRITE_SERIAL 1
#define SYS_EXIT         2

//****************************************************************************
// Estructura de registros guardados en la pila durante una interrupción
//****************************************************************************
typedef struct {
    uint64_t r15, r14, r13, r12, r11, r10, r9, r8;
    uint64_t rbp, rdi, rsi, rdx, rcx, rbx, rax;
    uint64_t int_no, err_code;
    uint64_t rip, cs, rflags, rsp, ss;
} __attribute__((packed)) interrupt_frame_t;

//****************************************************************************
// Función externa para inicializar la IDT (definida en idt64.c)
//****************************************************************************
extern void idt_init(void);

//****************************************************************************
// I/O en COM1
//****************************************************************************
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

//****************************************************************************
// Funciones del puerto serie: COM1
//****************************************************************************
void init_serial() {
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x80);
    outb(COM1 + 0, 0x03);
    outb(COM1 + 1, 0x00);
    outb(COM1 + 3, 0x03);
    outb(COM1 + 2, 0xC7);
    outb(COM1 + 4, 0x0B);
}

int is_transmit_empty() {
    return inb(COM1 + 5) & 0x20;
}

void write_serial(char c) {
    while (is_transmit_empty() == 0);
    outb(COM1, c);
}

void write_string_serial(const char* str) {
    while (*str) {
        write_serial(*str);
        str++;
    }
}

void write_hex64(uint64_t value) {
    const char hex[] = "0123456789ABCDEF";
    write_string_serial("0x");
    for (int i = 60; i >= 0; i -= 4) {
        write_serial(hex[(value >> i) & 0xF]);
    }
}

//****************************************************************************
// Handler de interrupciones genérico
//****************************************************************************
void isr_handler(interrupt_frame_t* frame) {
    write_string_serial("[KERNEL] Interrupcion recibida: Vector ");
    write_hex64(frame->int_no);
    write_string_serial(", Error Code: ");
    write_hex64(frame->err_code);
    write_string_serial("\r\n");
    write_string_serial("         RIP: ");
    write_hex64(frame->rip);
    write_string_serial("\r\n");

    // Para excepciones críticas, detener el sistema
    if (frame->int_no == 0 || frame->int_no == 6 ||
        frame->int_no == 8 || frame->int_no == 13 ||
        frame->int_no == 14) {
        write_string_serial("[KERNEL] PANIC! Excepcion critica. Sistema detenido.\r\n");
        __asm__ volatile("cli; hlt");
        while(1);
    }
}

//****************************************************************************
// Dispatcher de syscalls
//****************************************************************************
uint64_t syscall_dispatcher(uint64_t syscall_num, uint64_t arg1, uint64_t arg2,
                            uint64_t arg3, uint64_t arg4, uint64_t arg5) {
    switch (syscall_num) {
        case SYS_WRITE_SERIAL: {
            const char* str = (const char*)arg1;
            uint64_t len = arg2;

            for (uint64_t i = 0; i < len && str[i] != '\0'; i++) {
                write_serial(str[i]);
            }
            return len;
        }

        case SYS_EXIT: {
            write_string_serial("\r\n[KERNEL] Programa de usuario termino con codigo: ");
            write_hex64(arg1);
            write_string_serial("\r\n");
            return 0;
        }

        default:
            write_string_serial("[KERNEL] Syscall desconocida: ");
            write_hex64(syscall_num);
            write_string_serial("\r\n");
            return -1;
    }
}

//****************************************************************************
// Función para saltar a ring3
//****************************************************************************
void jump_to_userspace(uint64_t user_code_addr, uint64_t user_stack) {
    // Configurar segmentos de datos de usuario
    __asm__ volatile(
        "mov $0x23, %%ax\n"
        "mov %%ax, %%ds\n"
        "mov %%ax, %%es\n"
        "mov %%ax, %%fs\n"
        "mov %%ax, %%gs\n"
        ::: "ax"
    );

    // Preparar iretq para saltar a ring3
    __asm__ volatile(
        "push $0x23\n"           // SS
        "push %0\n"              // RSP
        "pushf\n"
        "pop %%rax\n"
        "or $0x200, %%rax\n"
        "push %%rax\n"           // RFLAGS
        "push $0x1B\n"           // CS
        "push %1\n"              // RIP
        "iretq\n"
        :
        : "r"(user_stack), "r"(user_code_addr)
        : "rax"
    );
}

//****************************************************************************
// Programa de usuario simple (en ring3)
//****************************************************************************
void __attribute__((section(".usercode"))) user_program() {
    const char* mensaje = "Hola desde ring3!\r\n";

    uint64_t len = 0;
    while (mensaje[len] != '\0') len++;

    uint64_t result;
    __asm__ volatile(
        "mov $1, %%rax\n"
        "mov %1, %%rdi\n"
        "mov %2, %%rsi\n"
        "int $0x80\n"
        "mov %%rax, %0\n"
        : "=r"(result)
        : "r"(mensaje), "r"(len)
        : "rax", "rdi", "rsi"
    );

    const char* mensaje2 = "Segunda syscall desde ring3!\r\n";
    len = 0;
    while (mensaje2[len] != '\0') len++;

    __asm__ volatile(
        "mov $1, %%rax\n"
        "mov %0, %%rdi\n"
        "mov %1, %%rsi\n"
        "int $0x80\n"
        :
        : "r"(mensaje2), "r"(len)
        : "rax", "rdi", "rsi"
    );

    __asm__ volatile(
        "mov $2, %%rax\n"
        "mov $42, %%rdi\n"
        "int $0x80\n"
        :
        :
        : "rax", "rdi"
    );

    while(1) {
        __asm__ volatile("hlt");
    }
}

//****************************************************************************
// Entry point del kernel
//****************************************************************************
void __attribute__((section(".text.entry")))
     __attribute__((used))
     __attribute__((noinline))
kernel_entry(void) {

    init_serial();

    write_string_serial("\r\n");
    write_string_serial("*************************************\r\n");
    write_string_serial("[KERNEL] Kernel cargado!\r\n");
    write_string_serial("[KERNEL] Modo Largo activo\r\n");
    write_string_serial("*************************************\r\n");

    write_string_serial("[KERNEL] Inicializando IDT...\r\n");
    idt_init();
    write_string_serial("[KERNEL] IDT inicializada y cargada!\r\n");

    write_string_serial("[KERNEL] Habilitando interrupciones...\r\n");
    __asm__ volatile("sti");
    write_string_serial("[KERNEL] Interrupciones habilitadas!\r\n");

    write_string_serial("\r\n");
    write_string_serial("[KERNEL] Preparando para saltar a ring3...\r\n");

    uint64_t user_stack = 0x8FFFF0;
    uint64_t user_code = (uint64_t)&user_program;

    write_string_serial("[KERNEL] Direccion del programa de usuario: ");
    write_hex64(user_code);
    write_string_serial("\r\n");
    write_string_serial("[KERNEL] Stack de usuario: ");
    write_hex64(user_stack);
    write_string_serial("\r\n");
    write_string_serial("[KERNEL] Saltando a ring3...\r\n");
    write_string_serial("\r\n");

    jump_to_userspace(user_code, user_stack);

    write_string_serial("[KERNEL] ERROR: Retorno inesperado de ring3\r\n");

    __asm__ volatile(
        "cli\n"
        "bucle:\n"
        "hlt\n"
        "jmp bucle\n"
    );

    __builtin_unreachable();
}
//****************************************************************************
// FIN.
//****************************************************************************
