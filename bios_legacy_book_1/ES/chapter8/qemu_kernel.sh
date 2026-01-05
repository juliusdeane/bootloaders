#!/bin/sh

CHAPTER=8
#WATCH_ACTIONS=int,cpu_reset,guest_errors,unimp,in_asm
WATCH_ACTIONS=cpu_reset,guest_errors,unimp,in_asm
RAM=1G

qemu-system-x86_64 -no-reboot \
                   -kernel vmlinuz-6.8.0-86-generic \
                   -initrd initrd.bootloader.cmp \
                   -append "console=tty0 rw rdinit=/init.sh debug" \
		               -serial stdio \
		               -vga std \
			             -m ${RAM} \
                   -d ${WATCH_ACTIONS} -D ch${CHAPTER}_detallado.log | tee ch${CHAPTER}_terminal.log
