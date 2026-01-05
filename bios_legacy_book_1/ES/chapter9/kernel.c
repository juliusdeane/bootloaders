#include <stdint.h>


void __attribute__((section(".text.entry")))
     __attribute__((used))
     __attribute__((noinline))
kernel_entry(void) {
    const char *cadena = "[KERNEL] Estamos dentro del kernel!";

    // Bucle infinito
    __asm__ volatile(
        "cli \n"
        "bucle: \n"
        "hlt \n"
        "jmp bucle \n"
    );

    // Ayuda para el compilador:
    // - no queremos que optimice.
    __builtin_unreachable();
}
