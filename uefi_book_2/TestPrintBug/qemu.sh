#!/bin/sh

RAM=1G
CHAPTER=TestPrintBug

# El primer parámetro:
# - si no está indicado, arrancamos disk.img por defecto.
DISK="${1:-disk.img}"

sudo qemu-system-x86_64 -cpu host -enable-kvm \
                        -boot order=c,menu=off \
                        -nographic \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
                        -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS_4M.fd \
                        -m $RAM -vga std -net none \
                        -netdev user,id=net0,tftp=./ \
                        -device virtio-net-pci,netdev=net0 \
                        -drive format=raw,unit=0,file="$DISK"
