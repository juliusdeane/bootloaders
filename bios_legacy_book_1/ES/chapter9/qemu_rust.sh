#!/bin/sh

CHAPTER=9
#WATCH_ACTIONS=int,cpu_reset,guest_errors,unimp,in_asm
WATCH_ACTIONS=cpu_reset,guest_errors,unimp,in_asm
RAM=1G

# -serial mon:stdio
# - para evitar que con ctrl-C cerremos la VM.
# - ahora con el clásico ctrl-A-x
qemu-system-x86_64 -drive file=disk_rust.img,format=raw,snapshot=on -no-reboot \
                   -serial mon:stdio \
                   -nographic \
                   -m ${RAM} \
                   -netdev user,id=net0,hostfwd=tcp::54321-:54321 -device virtio-net-pci,netdev=net0 \
                   -netdev user,id=net1 -device virtio-net-pci,netdev=net1 \
                   -netdev user,id=net2 -device virtio-net-pci,netdev=net2 \
                   -netdev user,id=net3 -device virtio-net-pci,netdev=net3 \
                   -d ${WATCH_ACTIONS} -D ch${CHAPTER}_detallado.log
