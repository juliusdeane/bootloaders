#include <stdio.h>
#include <unistd.h>

int main(void) {
    int contador = 0;

    while(1) {
        printf("[TEST0] Iteración: [%d]\n", contador);
        contador++;

        sleep(5);
    }
    return 0;
}