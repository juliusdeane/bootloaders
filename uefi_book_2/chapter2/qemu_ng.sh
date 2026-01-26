#!/bin/sh

RAM=1G
DISK=disk_initrd.img

sudo qemu-system-x86_64 -cpu host -enable-kvm \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_VARS.fd \
                        -m $RAM -vga std -net none \
                        -drive format=raw,unit=0,file=$DISK
