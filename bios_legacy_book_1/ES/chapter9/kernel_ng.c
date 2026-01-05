#include <stdint.h>

// Puertos del serial COM1
#define COM1 0x3F8

// Función para escribir un byte al puerto
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

// Función para leer un byte del puerto
static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// Inicializar el puerto serial COM1
void init_serial() {
    outb(COM1 + 1, 0x00);    // Disable all interrupts
    outb(COM1 + 3, 0x80);    // Enable DLAB (set baud rate divisor)
    outb(COM1 + 0, 0x03);    // Set divisor to 3 (lo byte) 38400 baud
    outb(COM1 + 1, 0x00);    //                  (hi byte)
    outb(COM1 + 3, 0x03);    // 8 bits, no parity, one stop bit
    outb(COM1 + 2, 0xC7);    // Enable FIFO, clear them, with 14-byte threshold
    outb(COM1 + 4, 0x0B);    // IRQs enabled, RTS/DSR set
}

// Verificar si el puerto está listo para transmitir
int is_transmit_empty() {
    return inb(COM1 + 5) & 0x20;
}

// Escribir un carácter al puerto serial
void write_serial(char c) {
    while (is_transmit_empty() == 0);
    outb(COM1, c);
}

// Escribir una cadena al puerto serial
void write_string_serial(const char* str) {
    while (*str) {
        write_serial(*str);
        str++;
    }
}

void __attribute__((section(".text.entry")))
     __attribute__((used))
     __attribute__((noinline))
kernel_entry(void) {

    // Inicializar el puerto serial
    init_serial();

    // Enviar mensaje de inicio
    write_string_serial("\r\n");
    write_string_serial("=====================================\r\n");
    write_string_serial("[KERNEL] Estamos dentro del kernel!\r\n");
    write_string_serial("[KERNEL] Modo largo funcionando!\r\n");
    write_string_serial("=====================================\r\n");
    write_string_serial("\r\n");

    // Bucle infinito
    __asm__ volatile(
        "cli \n"
        "bucle: \n"
        "hlt \n"
        "jmp bucle \n"
    );

    __builtin_unreachable();
}
