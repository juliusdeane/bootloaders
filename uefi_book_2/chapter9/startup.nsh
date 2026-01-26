fs0:
cd boot
vmlinuz initrd=\boot\initrd.cmp rdinit=/init.sh rw i915.modeset=0 nouveau.modeset=0 nomodeset vga=0 earlyprintk=vga,keep earlyprintk=serial earlyprintk=efi,keep console=tty0 console=ttyS0,115200
