#!/bin/sh

RAM=1G
CHAPTER=4
WATCH_ACTIONS=cpu_reset,guest_errors,unimp,in_asm

# El primer parámetro:
# - si no está indicado, arrancamos disk.img por defecto.
DISK="${1:-disk.img}"

sudo qemu-system-x86_64 -cpu host -enable-kvm \
                        -nographic \
                        -boot order=c,menu=off \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_VARS.fd \
                        -m $RAM -vga std -net none \
                        -d ${WATCH_ACTIONS} -D ch${CHAPTER}_detallado.log \
                        -drive format=raw,unit=0,file="$DISK"