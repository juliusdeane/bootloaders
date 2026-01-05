#!/bin/bash

INITRD_DIR=bootloader-initrd
INITRD_SUBNAME=bootloader

# Limpiar si existe
rm -rf initrd.$(INITRD_SUBNAME).gz
rm -rf $(INITRD_DIR)/{bin,sbin,etc,proc,sys,dev,newroot}

# Crear estructura
mkdir -p $(INITRD_DIR)/{bin,sbin,etc,proc,sys,dev,newroot}

# Copiar busybox
cp /bin/busybox $(INITRD_DIR)/bin/

# Crear enlaces simbólicos
cd $(INITRD_DIR)/bin
for cmd in sh ls cat cp mv rm mkdir mount umount ps kill ln poweroff; do
    ln -s busybox $cmd
done
cd ../..

# Crear dispositivos
cd $(INITRD_DIR)
sudo mknod dev/console c 5 1
sudo mknod dev/null c 1 3
sudo mknod dev/zero c 1 5

echo "[INIT] Copiando init.sh básico:"
cp bootloader_initrd_init.sh $(INITRD_DIR)/init.sh
chmod +x $(INITRD_DIR)/init.sh

# Crear initrd
find . | cpio -H newc -o | gzip > ../initrd.$(INITRD_SUBNAME).gz
cd ..

echo "initrd.$(INITRD_SUBNAME).gz creado exitosamente"
