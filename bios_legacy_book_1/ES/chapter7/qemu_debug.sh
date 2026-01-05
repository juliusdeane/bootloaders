#!/bin/sh
GDB_ADDRESS=127.127.127.1:1234
qemu-system-x86_64 -drive file=disk.img,format=raw,snapshot=on -no-reboot -serial stdio -gdb tcp:$GDB_ADDRESS -S
