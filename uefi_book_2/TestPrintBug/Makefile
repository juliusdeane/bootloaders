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

DISK := disk.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384

TARGET_NAME := TestPrintBug
TARGET := $(TARGET_NAME).efi
SOURCE := TestPrintBug.c

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

$(TARGET): $(SOURCE) $(DISK)
	@echo "[UEFI] [$(TARGET_NAME)] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -fs ../chapter3/edk2 edk2

	@mkdir -p edk2/$(TARGET_NAME)Pkg/$(TARGET_NAME)
	@cp -f $(SOURCE) edk2/$(TARGET_NAME)Pkg/$(TARGET_NAME)/$(SOURCE)
	@cp -f $(TARGET_NAME).inf edk2/$(TARGET_NAME)Pkg/$(TARGET_NAME)/$(TARGET_NAME).inf
	@cp -f $(TARGET_NAME).dsc edk2/$(TARGET_NAME)Pkg/$(TARGET_NAME)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(TARGET_NAME)Pkg/$(TARGET_NAME)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.
	@cp edk2/Build/$(TARGET_NAME)/DEBUG_GCC5/X64/$(TARGET) $(TARGET)

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
