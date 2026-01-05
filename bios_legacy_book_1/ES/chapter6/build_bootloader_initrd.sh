#!/bin/sh

INITRD_DIR=bootloader-initrd
INITRD_SUBNAME=bootloader
COMP=gzip
# COMP="zstd -6"


# Limpiar si existe
rm -f initrd.$INITRD_SUBNAME.gz
rm -rf $INITRD_DIR

# Crear estructura
mkdir -p $INITRD_DIR/bin
mkdir -p $INITRD_DIR/sbin
mkdir -p $INITRD_DIR/etc
mkdir -p $INITRD_DIR/proc
mkdir -p $INITRD_DIR/sys
mkdir -p $INITRD_DIR/dev
mkdir -p $INITRD_DIR/newroot

# Copiar busybox
cp /bin/busybox $INITRD_DIR/bin/

# Crear enlaces simbólicos
cd $INITRD_DIR/bin
for cmd in sh ls cat cp mv rm mkdir mount umount ps kill ln poweroff; do
    ln -s busybox $cmd
done
cd ../..

echo "[INIT] Entramos al directorio: $INITRD_DIR"
cd $INITRD_DIR

# Crear dispositivos

sudo mknod dev/console c 5 1
sudo mknod dev/null c 1 3
sudo mknod dev/zero c 1 5

echo "[INIT] Copiando init.sh básico:"
cp ../bootloader_initrd_init.sh ./init.sh

echo "[INIT] init.sh +ejecutable:"
chmod +x ./init.sh

# Crear initrd
find . | cpio -H newc -o | $COMP > ../initrd.$INITRD_SUBNAME.cmp

echo "[INIT] Salimos del directorio: $INITRD_DIR"
cd ..

echo "[OK] initrd.$INITRD_SUBNAME.gz creado exitosamente"
echo
