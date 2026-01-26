DD := dd
CP := cp
RM := rm
MKDIR := mkdir
LN := ln

MOUNT := mount
UMOUNT := umount
PARTED := parted
LOSETUP := losetup
MKFS_VFAT := mkfs.vfat
MKFS_EXT4 := mkfs.ext4

PYTHON3 := venv/bin/python3
CC := gcc
LD := ld
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

TARGET_NAME := bootx64
TARGET := $(TARGET_NAME).efi
SOURCE := bootx64.c

all: $(TARGET)
# startup.nsh:
	@echo "[UEFI] [$(TARGET)] Preparamos startup.nsh:"
	@echo "fs0:" > startup.nsh
	@echo "cd boot" >> startup.nsh
	@echo "vmlinuz initrd=\\\\boot\\\\initrd.cmp rdinit=/init.sh rw i915.modeset=0 nouveau.modeset=0 nomodeset vga=0 earlyprintk=vga,keep earlyprintk=serial earlyprintk=efi,keep console=tty0 console=ttyS0,115200" >> startup.nsh

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$($(LOSETUP) -a | grep $(DISK) | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] [$(TARGET)] Loop device: $$LOOP_DEV"; \
		echo "[UEFI] [$(TARGET)] Montar particiones:"; \
		sudo $(MOUNT) $${LOOP_DEV}p1 EFI/; \
		sleep 5; \
		echo "[UEFI] [$(TARGET)] Copiar aplicaciones EFI:"; \
		sudo $(CP) startup.nsh EFI/startup.nsh ; \
		sudo $(CP) $(TARGET) EFI/EFI/BOOT/BOOTX64.EFI ; \
		echo "[UEFI] [$(TARGET)] DES-montar particiones:"; \
		sudo $(UMOUNT) EFI/; \
		sudo $(LOSETUP) -d $$LOOP_DEV; \
		echo "[UEFI] [$(TARGET)] <completado>"; \
		echo

$(TARGET): $(SOURCE) tools.c $(DISK)
	@echo "[UEFI] [$(TARGET)] (Carga del kernel de Linux) Compilando C:"

	@$(CC) $(CFLAGS) -c $(SOURCE) -o $(TARGET_NAME).o
	@$(CC) $(CFLAGS) -c tools.c -o tools.o

	@echo "[UEFI] [$(TARGET)] (C-version/gnu-efi) Linker  .o  => .so:"
	@$(LD) -shared -Bsymbolic -L$(LIB) -L$(LIB) \
                   -T$(EFI_LDS) $(EFI_CRT_OBJS) \
                   $(TARGET_NAME).o tools.o -o $(TARGET_NAME).so -lgnuefi -lefi

	@echo "[UEFI] [$(TARGET)] (C-version/gnu-efi) objcopy .so => PE32+: stub.efi"
	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                $(TARGET_NAME).so $(TARGET)
	@echo "[UEFI] [$(TARGET)] Terminado."
	@echo

$(DISK):
	@echo "[UEFI] [$(TARGET)] DISK Fabrik:"
# Forzamos la creación del enlace, revisa que RESOURCES esté donde apunta.
	@echo "[UEFI] [$(TARGET)] Creando enlace a RESOURCES desde: [../../../RESOURCES/]"
	@$(LN) -fs ../../../RESOURCES/
	@$(RM) -f $(DISK)
	@$(DD) if=/dev/zero of=$(DISK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_SIZE)
# Vamos a usar el disco entero para FAT32.
	@sudo $(PARTED) $(DISK) mklabel gpt
	@sudo $(PARTED) $(DISK) mkpart primary fat32 1MiB 100%
	@sudo $(PARTED) $(DISK) set 1 esp on

# Asegurar EFI/:
	@$(MKDIR) -p EFI/

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$($(LOSETUP) -a | grep $(DISK) | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] [$(TARGET)] Loop device: $$LOOP_DEV"; \
		echo "[UEFI] [$(TARGET)] Asegurar sistema de fichero:"; \
		sudo $(MKFS_VFAT) -F32 $${LOOP_DEV}p1; \
		echo "[UEFI] [$(TARGET)] Montar particiones:"; \
		sudo $(MOUNT) $${LOOP_DEV}p1 EFI/; \
		sleep 5; \
		echo "[UEFI] [$(TARGET)] Asegurar directorios:"; \
		sudo $(MKDIR) -p EFI/EFI/BOOT; \
		sudo $(MKDIR) -p EFI/BOOT; \
		echo "[UEFI] [$(TARGET)] Copiar recursos del kernel:"; \
		sudo $(CP) RESOURCES/vmlinuz-6.8.0-86-generic EFI/BOOT/vmlinuz ; \
		sudo $(CP) RESOURCES/initrd.bootloader.cmp EFI/BOOT/initrd.cmp ; \
		echo "[UEFI] [$(TARGET)] DES-montar particiones:"; \
		sudo $(UMOUNT) EFI/; \
		sudo $(LOSETUP) -d $$LOOP_DEV; \
		echo "[UEFI] [$(TARGET)] $(DISK) <completado>"; \
		echo

clean:
	@echo "[UEFI] [$(TARGET)] Limpiando:"
	@$(RM) -f startup.nsh *.o *.so $(TARGET) *.log $(DISK)
	@echo "..."
	@$(RM) -rf EFI/
	@echo "[UEFI] [$(TARGET)] Limpiado OK."
	@echo
