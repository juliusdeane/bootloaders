#include <stdio.h>


int main(void) {
    printf("¡Hola bootloaders!\nEntramos en un bucle infinito para usar gdb.\n\n");
    while(1) { /* no hacemos nada */ }
    return 0;
}
