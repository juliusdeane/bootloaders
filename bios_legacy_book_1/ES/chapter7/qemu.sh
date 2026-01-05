#!/bin/sh
qemu-system-x86_64 -drive file=disk.img,format=raw,snapshot=on -serial stdio

