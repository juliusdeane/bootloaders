#!/bin/sh

KERNEL_VERSION=6.8.0-86-generic
INITRD_DIR=bootloader-initrd
INITRD_SUBNAME=bootloader
INITRD_ORIGINAL=initrd-6.8.0-86-generic
COMP=gzip
# COMP="zstd -6"

# FRIDA releases
FRIDA_HOME=../frida
FRIDA_LINUX=frida-server-17.5.1-linux-x86_64
FRIDA_LINUX_RELEASE=https://github.com/frida/frida/releases/download/17.5.1/frida-server-17.5.1-linux-x86_64.xz
FRIDA_LINUX_MUSL=frida-server-17.5.1-linux-x86_64
FRIDA_LINUX_MUSL_RELEASE=https://github.com/frida/frida/releases/download/17.5.1/frida-server-17.5.1-linux-x86_64-musl.xz
FRIDA_WIN32=frida-server-17.5.1-windows-x86.exe
FRIDA_WIN32_RELEASE=https://github.com/frida/frida/releases/download/17.5.1/frida-server-17.5.1-windows-x86.exe.xz
FRIDA_WIN64=frida-server-17.5.1-windows-x86_64.exe
FRIDA_WIN64_RELEASE=https://github.com/frida/frida/releases/download/17.5.1/frida-server-17.5.1-windows-x86_64.exe.xz

PYTHON_BASE=../python
PYTHON_HOME=$PYTHON_BASE/Python-3.11.13
PYTHON3_BINARY=$PYTHON_HOME/python
PYTHON3_LIB=$PYTHON_HOME/Lib
PYTHON3_RELEASE=https://www.python.org/ftp/python/3.11.13/Python-3.11.13.tar.xz

TEST_BASE=..
TEST0_BINARY=$TEST_BASE/test0
TEST0_SOURCE=$TEST_BASE/test0.c

# Limpiar si existe
rm -f initrd.$INITRD_SUBNAME.gz
rm -rf $INITRD_DIR

# Crear estructura:

# GLIBC:
mkdir -p $INITRD_DIR/lib64/x86_64-linux-gnu
mkdir -p $INITRD_DIR/lib/x86_64-linux-gnu/

# Binarios:
mkdir -p $INITRD_DIR/bin
# Para bash-static
mkdir -p $INITRD_DIR/usr/bin
mkdir -p $INITRD_DIR/sbin
mkdir -p $INITRD_DIR/usr/local/bin
mkdir -p $INITRD_DIR/usr/local/sbin
# Lib para python y otros
mkdir -p $INITRD_DIR/usr/local/lib
# Requisitos:
mkdir -p $INITRD_DIR/etc
mkdir -p $INITRD_DIR/proc
mkdir -p $INITRD_DIR/sys
mkdir -p $INITRD_DIR/dev
mkdir -p $INITRD_DIR/newroot
# HOMES: user por defecto.
mkdir -p $INITRD_DIR/home/user
##############################################################################
# Módulos:
##############################################################################
# Creamos MODULES:
mkdir -p $INITRD_DIR/lib/modules
mkdir -p $INITRD_DIR/lib/modules/$KERNEL_VERSION/kernel/drivers/net/usb

# Subsistema USB:
# cp -a $INITRD_ORIGINAL/main/lib/modules/6.8.0-86-generic/kernel/drivers/usb $INITRD_DIR/lib/modules/$KERNEL_VERSION/kernel/drivers/
# NETWORK modules:
# cp -a $INITRD_ORIGINAL/main/lib/modules/6.8.0-86-generic/kernel/drivers/net/usb $INITRD_DIR/lib/modules/$KERNEL_VERSION/kernel/drivers/net/

# ¡COPIA INTEGRAL!
# - ya veremos qué necesitamos y qué no.
# cp -a $INITRD_ORIGINAL/main/lib/modules $INITRD_DIR/lib/

##############################################################################
# BusyBox:
##############################################################################
# Copiar busybox
cp /bin/busybox $INITRD_DIR/bin/

# Crear enlaces simbólicos
cd $INITRD_DIR/bin
for cmd in id sh ls cat cp mv rm mkdir mount umount ps kill ln poweroff; do
    ln -s busybox $cmd
done
cd ../..

echo "[INIT] Entramos al directorio: $INITRD_DIR"
cd $INITRD_DIR

# GLIBC:
# - podríamos haber elegido musl, pero por ahora, me sirve.
# Copiar glibc básica al initrd
cp -a /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 lib/x86_64-linux-gnu/
cd lib64/
cp -a ../lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ld-linux-x86-64.so.2
cd ..
cp -a /lib/x86_64-linux-gnu/libc.* lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/libm.so.6 lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/libdl.so.2 lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/libpthread.so.0 lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/librt.so.1 lib/x86_64-linux-gnu/

# Copiar .profile
cp ../bootloader_profile .profile

# Copiar passwd (user names en id):
cp ../bootloader_initrd_passwd etc/passwd
cp ../bootloader_initrd_group etc/group

# Copiar bash-static
cp /usr/bin/bash-static usr/bin/bash
chmod +x usr/bin/bash

# Copiar python static
# - donde tengas el binario.
#cp ../python3.11_static/Python-3.11.14/python usr/local/bin
if [ ! -f "$PYTHON3_BINARY" ]; then
    echo "[PYTHON3] [STATIC] $PYTHON3_BINARY no existe."
    echo "    Descargando> $PYTHON3_RELEASE:"
    wget -q -O - "$PYTHON3_RELEASE" | tar -xJf - -C $PYTHON_BASE
    # Verificar la descarga
    if [ $? -eq 0 ]; then
        echo "[PYTHON3] [STATIC] Descarga OK."
    else
        echo "[PYTHON3] [STATIC] Descarga ERROR. Salimos."
        exit 1
    fi

    # Compilar:
    cd $PYTHON_HOME
    ./configure \
      --prefix=/usr/local \
      --enable-optimizations \
      --with-lto \
      --enable-shared=no \
      --disable-shared \
      LDFLAGS="-static -static-libgcc" \
      CFLAGS="-static" \
      CPPFLAGS="-static -fPIC" \
      DYNLOADFILE="dynload_stub.o" \
      LINKFORSHARED=" " \
      --with-ensurepip=install \
      --with-system-ffi=no \
      --with-builtin-hashlib-hashes=md5,sha1,sha256,sha512,sha3,blake2 \
      --enable-loadable-sqlite-extensions=no \
      --prefix=/usr/local/
      make LDFLAGS="-Wl,-no-export-dynamic -static-libgcc -static" LINKFORSHARED=" "

      cd ..
else
    echo "[PYTHON3] [STATIC] El fichero $PYTHON3_BINARY existe. Continuamos."
fi

echo "[PYTHON3] [STATIC] Copiar $PYTHON3_BINARY a usr/local/bin:"
cp -a $PYTHON3_BINARY usr/local/bin
# Creamos un alias para staticpython:
# - para evitar potenciales conflictos con versiones de python
#   que puedan encontrarse en el sistema, nosotros siempre nos
#   referiremos al nuestro como staticpython.
ln -s usr/local/bin/python usr/local/bin/staticpython
cp -a $PYTHON3_LIB usr/local/lib/python3.11

# Crear recursos en /etc:
# - udhcpc: dhcp client.
mkdir -p etc/udhcpc
cp ../bootloader_initrd_udhcpc.script etc/udhcpc/default.script
chmod +x etc/udhcpc/default.script

# FRIDA: copiar frida-server
# FRIDA: ¿por qué? ¡Porque sí!
if [ ! -f "$FRIDA_HOME/$FRIDA_LINUX" ]; then
    echo "[FRIDA] [LINUX] $FRIDA_HOME/$FRIDA_LINUX no existe."
    echo "    Descargando> $FRIDA_LINUX_RELEASE:"
    #wget -O "$TEMP_DIR/_temp.xz" "$FRIDA_LINUX_RELEASE"
    #unxz -c "$FRIDA_HOME/_temp.xz" > "$FRIDA_HOME/$FRIDA_LINUX"
    #rm -f "$TEMP_DIR/_temp.xz"

    wget -q -O - "$FRIDA_LINUX_RELEASE" | unxz > $FRIDA_HOME/$FRIDA_LINUX

    # Verificar la descarga
    if [ $? -eq 0 ]; then
        echo "[FRIDA] [LINUX] Descarga OK."
    else
        echo "[FRIDA] [LINUX] Descarga ERROR. Salimos."
        exit 1
    fi
else
    echo "[FRIDA] [LINUX] El fichero $FRIDA_HOME/$FRIDA_LINUX existe. Continuamos."
fi

if [ ! -f "$FRIDA_HOME/$FRIDA_WIN32" ]; then
    echo "[FRIDA] [WINDOWS] $FRIDA_HOME/$FRIDA_WIN32 no existe."
    echo "    Descargando> $FRIDA_WIN32_RELEASE:"
    wget -q -O - "$FRIDA_WIN32_RELEASE" | unxz > $FRIDA_HOME/$FRIDA_WIN32

    # Verificar la descarga
    if [ $? -eq 0 ]; then
        echo "[FRIDA] [WINDOWS] Descarga OK."
    else
        echo "[FRIDA] [WINDOWS] Descarga ERROR. Salimos."
        exit 1
    fi
else
    echo "[FRIDA] [WINDOWS] El fichero $FRIDA_HOME/$FRIDA_WIN32 existe. Continuamos."
fi

if [ ! -f "$FRIDA_HOME/$FRIDA_WIN64" ]; then
    echo "[FRIDA] [WINDOWS] $FRIDA_HOME/$FRIDA_WIN64 no existe."
    echo "    Descargando> $FRIDA_WIN64_RELEASE:"
    wget -q -O - "$FRIDA_WIN64_RELEASE" | unxz > $FRIDA_HOME/$FRIDA_WIN64

    # Verificar la descarga
    if [ $? -eq 0 ]; then
        echo "[FRIDA] [WINDOWS] Descarga OK."
    else
        echo "[FRIDA] [WINDOWS] Descarga ERROR. Salimos."
        exit 1
    fi
else
    echo "[FRIDA] [WINDOWS] El fichero $FRIDA_HOME/$FRIDA_WIN64 existe. Continuamos."
fi

echo "[FRIDA] Copiamos los recursos de Frida:"
cp -a ../frida/ usr/local/
chmod +x usr/local/frida/*

# Crear dispositivos mínimos
sudo mknod dev/console c 5 1
sudo mknod dev/null c 1 3
sudo mknod dev/zero c 1 5

# Crear tty*
sudo mknod dev/tty c 5 0
sudo mknod dev/tty0 c 4 0
sudo mknod dev/tty1 c 4 1
sudo mknod dev/tty2 c 4 2
sudo mknod dev/tty3 c 4 3
sudo mknod dev/tty4 c 4 4

# Crear SERIAL
sudo mknod dev/ttyS0 c 4 64
sudo mknod dev/ttyS1 c 4 65
sudo mknod dev/ttyS2 c 4 66
sudo mknod dev/ttyS3 c 4 67
sudo mknod dev/ttyS4 c 4 68

echo "[INIT] Copiando init.sh básico:"
cp ../bootloader_initrd_init.sh ./init.sh

echo "[INIT] init.sh +ejecutable:"
chmod +x ./init.sh

if [ ! -f "$TEST0_BINARY" ]; then
    echo "[TEST] [TEST0] $TEST0_BINARY no existe. Compilando:"
    gcc -o $TEST0_BINARY $TEST0_SOURCE

    # Verificar la descarga
    if [ $? -eq 0 ]; then
        echo "[TEST] [TEST0] Compilación OK."
    else
        echo "[TEST] [TEST0] Compilación ERROR. Salimos."
        exit 1
    fi
else
    echo "[TEST] [TEST0] El fichero $TEST0_BINARY existe. Continuamos."
fi

# Ejecutables de test:
mkdir -p usr/test
cp ../test[0123456789] usr/test
chmod +x usr/test/*

# Crear initrd
find . | cpio -H newc -o | $COMP > ../initrd.$INITRD_SUBNAME.cmp

echo "[INIT] Salimos del directorio: $INITRD_DIR"
cd ..

echo "[OK] initrd.$INITRD_SUBNAME.gz creado exitosamente"
echo
