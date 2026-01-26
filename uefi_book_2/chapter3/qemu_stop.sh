#!/bin/sh

RAM=1G

# El primer parámetro:
# - si no está indicado, arrancamos disk.img por defecto.
DISK="${1:-disk.img}"

# Con los OVMF originales y no los de 4MB.
sudo qemu-system-x86_64 -cpu host -enable-kvm \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
                        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_VARS.fd \
                        -m $RAM -vga std -net none \
			                  -S -monitor stdio \
                        -drive format=raw,unit=0,file="$DISK"
