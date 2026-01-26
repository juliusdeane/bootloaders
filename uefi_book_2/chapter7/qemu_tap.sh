#!/bin/sh

RAM=1G
CHAPTER=7
WATCH_ACTIONS=cpu_reset,guest_errors,unimp,in_asm

# El primer parámetro:
# - si no está indicado, arrancamos disk.img por defecto.
DISK="${1:-disk.img}"

sudo qemu-system-x86_64 -cpu host -enable-kvm \
                        -nographic \
                        -boot order=c,menu=off \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
                        -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS_4M.fd \
                        -m $RAM -vga std -net none \
                        -netdev bridge,id=net0,br=virbr1 \
                        -device virtio-net-pci,netdev=net0 \
                        -d ${WATCH_ACTIONS} -D ch${CHAPTER}_detallado.log \
                        -drive format=raw,unit=0,file="$DISK"
