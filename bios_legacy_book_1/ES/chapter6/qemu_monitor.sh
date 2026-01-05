#!/bin/sh
qemu-system-x86_64 -drive file=disk.img,format=raw,snapshot=on -no-reboot \
		               -serial stdio \
		               -vga std \
                   -d int,cpu_reset,guest_errors,unimp,in_asm -D ch6_detallado.log | tee ch6_terminal.log
