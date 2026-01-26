#!/bin/sh

RAM=1G
CHAPTER=11
# guest_errors añade mucho ruido.
#WATCH_ACTIONS=cpu_reset,guest_errors,unimp,in_asm
WATCH_ACTIONS=cpu_reset,unimp,in_asm

sudo qemu-system-x86_64 -cpu host -enable-kvm \
                        -boot order=c,menu=off \
			                  -nographic \
                        -vga std \
                        -device virtio-gpu-pci \
                        -drive if=pflash,format=raw,readonly=off,file=./OVMF_CODE.fd \
                        -drive if=pflash,format=raw,readonly=off,file=./OVMF_VARS.fd \
                        -m $RAM -vga std -net none \
                        -netdev user,id=net0,tftp=./ \
                        -device virtio-net-pci,netdev=net0 \
                        -d ${WATCH_ACTIONS} -D ch${CHAPTER}_detallado.log \
                        -drive format=raw,unit=0,file="disk_mok.img"
