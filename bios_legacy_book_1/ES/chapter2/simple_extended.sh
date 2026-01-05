#!/bin/sh

# Compilamos el fuente:
nasm -f bin simple_disk_extended.asm -o simple_disk_extended.bin

# Creamos un disco de 2 sectores, cada uno de 512 bytes.
dd if=/dev/zero of=disk_2sectores.img bs=512 count=2

# Ahora añadimos el sector1 (RECUERDA conv=notrunc)
dd if=simple_disk_extended.bin of=disk_2sectores.img bs=512 count=1 conv=notrunc

# Finalmente, tenemos que incorporar las letras A
# Si no tienes el fichero lleno de letras A, recuerda que puedes crearlo así:
# perl -e 'print "A" x 512;' > fichero_A.txt
#
# Para este nuevo ejemplo vamos a usar letras B:
perl -e 'print "B" x 512;' > fichero_B.txt

# Reemplazamos los nulos por nuestras B (seek=1, notrunc, recordemos)
dd if=fichero_B.txt of=disk_2sectores.img bs=512 count=1 seek=1 conv=notrunc

# Lanzamos con QEMU:
qemu-system-x86_64 -drive \
                   file=disk_2sectores.img,format=raw,snapshot=on \
                   -serial stdio
