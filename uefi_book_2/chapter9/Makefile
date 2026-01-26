DD := dd
LOSETUP := losetup
MKFS_VFAT := mkfs.vfat
MKFS_EXT4 := mkfs.ext4
PARTED := parted
LOSETUP := losetup
PYTHON3 := venv/bin/python3

CC := gcc
LD := ld
CP := cp
OBJCOPY := objcopy

ARCH            =  x86_64
EFIINC          = /usr/include/efi
EFIINCS         = -I$(EFIINC)
LIB             = /usr/lib
LIB32           = /usr/lib32
EFI_CRT_OBJS    = /usr/lib/crt0-efi-x86_64.o
EFI_LDS         = /usr/lib/elf_x86_64_efi.lds
CFLAGS          = $(EFIINCS) -DEFI_FUNCTION_WRAPPER \
                             -ffreestanding -fpic \
                             -fno-stack-check -fno-stack-protector \
                             -fshort-wchar -mno-red-zone -maccumulate-outgoing-args \
                             -Wall

DISK := disk.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384


all: stub
# startup.nsh:
	@echo "fs0:" > startup.nsh
	@echo "cd boot" >> startup.nsh
	@echo "vmlinuz initrd=\\\\boot\\\\initrd.cmp rdinit=/init.sh rw i915.modeset=0 nouveau.modeset=0 nomodeset vga=0 earlyprintk=vga,keep earlyprintk=serial earlyprintk=efi,keep console=tty0 console=ttyS0,115200" >> startup.nsh

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$($(LOSETUP) -a | grep $(DISK) | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] Loop device: $$LOOP_DEV"; \
		echo "[UEFI] Montar particiones:"; \
		sudo mount $${LOOP_DEV}p1 EFI/; \
		sleep 5; \
		echo "[UEFI] Copiar aplicaciones EFI:"; \
		sudo cp startup.nsh EFI/startup.nsh ; \
		sudo cp stub.efi EFI/EFI/BOOT/stub.efi ; \
#		sudo cp stub.efi EFI/EFI/BOOT/BOOTX64.EFI ; \
		echo "[UEFI] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] <completado>"; \
		echo

stub: stub.c tools.c
	@echo "[UEFI] [STUB] (Carga del kernel de Linux) Compilando C:"

	@$(CC) $(CFLAGS) -c stub.c -o stub.o
	@$(CC) $(CFLAGS) -c tools.c -o tools.o

	@echo "[UEFI] [STUB] (C-version/gnu-efi) Linker  .o  => .so:"
	@$(LD) -shared -Bsymbolic -L$(LIB) -L$(LIB) \
                   -T$(EFI_LDS) $(EFI_CRT_OBJS) \
                   stub.o tools.o -o stub.so -lgnuefi -lefi

	@echo "[UEFI] [STUB] (C-version/gnu-efi) objcopy .so => PE32+: stub.efi"
	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                stub.so stub.efi
	@echo "[UEFI] [STUB] Terminado."
	@echo

$(DISK):
	@echo "[UEFI] [STUB] DISK Fabrik:"
	@rm -f $(DISK)
	@$(DD) if=/dev/zero of=$(DISK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_SIZE)
# Vamos a usar el disco entero para FAT32.
	@sudo $(PARTED) $(DISK) mklabel gpt
	@sudo $(PARTED) $(DISK) mkpart primary fat32 1MiB 100%
	@sudo $(PARTED) $(DISK) set 1 esp on

# Asegurar EFI/:
	@mkdir -p EFI/

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$($(LOSETUP) -a | grep $(DISK) | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] Loop device: $$LOOP_DEV"; \
		echo "[UEFI] Asegurar sistema de fichero:"; \
		sudo $(MKFS_VFAT) -F32 $${LOOP_DEV}p1; \
		echo "[UEFI] Montar particiones:"; \
		sudo mount $${LOOP_DEV}p1 EFI/; \
		sleep 5; \
		echo "[UEFI] Asegurar directorios:"; \
		sudo mkdir -p EFI/EFI/BOOT; \
		sudo mkdir -p EFI/BOOT; \
		echo "[UEFI] Copiar recursos del kernel:"; \
		sudo cp RESOURCES/vmlinuz-6.8.0-86-generic EFI/BOOT/vmlinuz ; \
		sudo cp RESOURCES/initrd.bootloader.cmp EFI/BOOT/initrd.cmp ; \
		echo "[UEFI] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] $(DISK) <completado>"; \
		echo

clean:
	@rm -f startup.nsh *.o *.so *.efi *.log $(DISK)
	@rm -rf EFI/
