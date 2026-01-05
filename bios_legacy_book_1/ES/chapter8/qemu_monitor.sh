#!/bin/sh

CHAPTER=8
#WATCH_ACTIONS=int,cpu_reset,guest_errors,unimp,in_asm
WATCH_ACTIONS=cpu_reset,guest_errors,unimp,in_asm
RAM=1G

qemu-system-x86_64 -drive file=disk.img,format=raw,snapshot=on -no-reboot \
		               -serial stdio \
		               -vga std \
                   -m ${RAM} \
                   -d ${WATCH_ACTIONS} -D ch${CHAPTER}_detallado.log | tee ch${CHAPTER}_terminal.log
