#!/bin/sh

RAM=1G
DISK=disk.img

qemu-system-x86_64 -cpu qemu64 -bios /usr/share/qemu/OVMF.fd \
                   -m $RAM -vga std -net none \
                   -drive format=raw,unit=0,file=$DISK
