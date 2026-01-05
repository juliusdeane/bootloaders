// kernel.c - Kernel básico para modo largo (64 bits)

// Definir tipo de datos básicos
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

// Dirección del buffer de video en modo texto
#define VIDEO_MEMORY 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

// Colores VGA
#define COLOR_BLACK 0
#define COLOR_BLUE 1
#define COLOR_GREEN 2
#define COLOR_CYAN 3
#define COLOR_RED 4
#define COLOR_MAGENTA 5
#define COLOR_BROWN 6
#define COLOR_LIGHT_GREY 7
#define COLOR_DARK_GREY 8
#define COLOR_LIGHT_BLUE 9
#define COLOR_LIGHT_GREEN 10
#define COLOR_LIGHT_CYAN 11
#define COLOR_LIGHT_RED 12
#define COLOR_LIGHT_MAGENTA 13
#define COLOR_YELLOW 14
#define COLOR_WHITE 15

// Función para crear atributo de color
static inline uint8_t vga_entry_color(uint8_t fg, uint8_t bg) {
    return fg | (bg << 4);
}

// Función para crear entrada VGA
static inline uint16_t vga_entry(unsigned char uc, uint8_t color) {
    return (uint16_t) uc | ((uint16_t) color << 8);
}

// Variables globales del terminal
static uint16_t* terminal_buffer;
static uint8_t terminal_color;
static uint32_t terminal_row;
static uint32_t terminal_column;

// Inicializar el terminal
void terminal_initialize(void) {
    terminal_buffer = (uint16_t*) VIDEO_MEMORY;
    terminal_color = vga_entry_color(COLOR_LIGHT_GREEN, COLOR_BLACK);
    terminal_row = 0;
    terminal_column = 0;

    // Limpiar pantalla
    for (uint32_t y = 0; y < VGA_HEIGHT; y++) {
        for (uint32_t x = 0; x < VGA_WIDTH; x++) {
            const uint32_t index = y * VGA_WIDTH + x;
            terminal_buffer[index] = vga_entry(' ', terminal_color);
        }
    }
}

// Establecer color
void terminal_setcolor(uint8_t color) {
    terminal_color = color;
}

// Poner un carácter en la posición actual
void terminal_putentryat(char c, uint8_t color, uint32_t x, uint32_t y) {
    const uint32_t index = y * VGA_WIDTH + x;
    terminal_buffer[index] = vga_entry(c, color);
}

// Scroll de una línea
void terminal_scroll(void) {
    // Mover todas las líneas una posición arriba
    for (uint32_t y = 0; y < VGA_HEIGHT - 1; y++) {
        for (uint32_t x = 0; x < VGA_WIDTH; x++) {
            terminal_buffer[y * VGA_WIDTH + x] = terminal_buffer[(y + 1) * VGA_WIDTH + x];
        }
    }

    // Limpiar última línea
    for (uint32_t x = 0; x < VGA_WIDTH; x++) {
        terminal_buffer[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = vga_entry(' ', terminal_color);
    }
}

// Escribir un carácter
void terminal_putchar(char c) {
    if (c == '\n') {
        terminal_column = 0;
        terminal_row++;
    } else {
        terminal_putentryat(c, terminal_color, terminal_column, terminal_row);
        terminal_column++;

        if (terminal_column >= VGA_WIDTH) {
            terminal_column = 0;
            terminal_row++;
        }
    }

    if (terminal_row >= VGA_HEIGHT) {
        terminal_scroll();
        terminal_row = VGA_HEIGHT - 1;
    }
}

// Escribir una cadena
void terminal_writestring(const char* data) {
    uint32_t i = 0;
    while (data[i] != '\0') {
        terminal_putchar(data[i]);
        i++;
    }
}

// Función simple para hacer busy-wait
void delay(uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        __asm__ volatile ("nop");
    }
}

// Punto de entrada del kernel
void kernel_entry(void) {
    // Inicializar terminal
    terminal_initialize();

    // Escribir mensaje de bienvenida
    terminal_setcolor(vga_entry_color(COLOR_YELLOW, COLOR_BLACK));
    terminal_writestring("===================================\n");
    terminal_setcolor(vga_entry_color(COLOR_LIGHT_CYAN, COLOR_BLACK));
    terminal_writestring("   Kernel en Modo Largo (64-bit)\n");
    terminal_setcolor(vga_entry_color(COLOR_YELLOW, COLOR_BLACK));
    terminal_writestring("===================================\n\n");

    terminal_setcolor(vga_entry_color(COLOR_LIGHT_GREEN, COLOR_BLACK));
    terminal_writestring("Estado: ");
    terminal_setcolor(vga_entry_color(COLOR_WHITE, COLOR_BLACK));
    terminal_writestring("Kernel cargado correctamente!\n\n");

    terminal_setcolor(vga_entry_color(COLOR_LIGHT_GREEN, COLOR_BLACK));
    terminal_writestring("Modo: ");
    terminal_setcolor(vga_entry_color(COLOR_WHITE, COLOR_BLACK));
    terminal_writestring("64-bit Long Mode activado\n\n");

    terminal_setcolor(vga_entry_color(COLOR_LIGHT_GREEN, COLOR_BLACK));
    terminal_writestring("Sistema: ");
    terminal_setcolor(vga_entry_color(COLOR_WHITE, COLOR_BLACK));
    terminal_writestring("Bootloader custom funcionando\n\n");

    terminal_setcolor(vga_entry_color(COLOR_CYAN, COLOR_BLACK));
    terminal_writestring("El kernel esta ejecutandose...\n");

    // Loop infinito
    while(1) {
        __asm__ volatile ("hlt");
    }
}
