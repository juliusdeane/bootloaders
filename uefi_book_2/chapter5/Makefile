DD := dd
CP := cp
MKFS_VFAT := mkfs.vfat
MKFS_EXT4 := mkfs.ext4

PARTED := parted
LOSETUP := losetup
PYTHON3 := venv/bin/python3

CHAPTER := Chapter5
BOOTLOADER_NAME := bootloader
BOOTLOADER := $(BOOTLOADER_NAME).c
BOOTLOADER_INF := $(BOOTLOADER_NAME).inf
BOOTLOADER_DSC := $(BOOTLOADER_NAME).dsc
BOOTLOADER_ARTIFACT := $(BOOTLOADER_NAME).efi
BUILT_ARTIFACT := edk2/Build/$(BOOTLOADER_NAME)/DEBUG_GCC5/X64/$(BOOTLOADER_ARTIFACT)

DISK := disk.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384


all: clean $(BOOTLOADER_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] BOOTX64.EFI/EDK2 Fabrik:"
	@echo

# Por si acaso:
	@mkdir -p EFI/
	@mkdir -p BOOT/
	@mkdir -p ROOT/

	@echo "[UEFI] [BOOTLOADER] Copiar $(BOOTLOADER_ARTIFACT):"
	@$(CP) $(BUILT_ARTIFACT) $(BOOTLOADER_ARTIFACT)
	@echo "[UEFI] [BOOTLOADER] Copiar $(BOOTLOADER_ARTIFACT) (BOOTX64):"
	@$(CP) $(BUILT_ARTIFACT) BOOTX64.EFI

	@echo "[UEFI] [BOOTLOADER] DISK Fabrik:"
	@$(DD) if=/dev/zero of=$(DISK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_SIZE)

	@sudo $(PARTED) $(DISK) mklabel gpt
	@sudo $(PARTED) $(DISK) mkpart primary fat32 1MiB 513MiB
	@sudo $(PARTED) $(DISK) set 1 esp on
	@sudo $(PARTED) $(DISK) mkpart primary ext4 513MiB 100%

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$($(LOSETUP) -a | grep $(DISK) | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] [BOOTLOADER] Loop device: $$LOOP_DEV"; \
		sudo $(MKFS_VFAT) -F32 $${LOOP_DEV}p1; \
		sudo $(MKFS_EXT4) $${LOOP_DEV}p2; \
		echo "[UEFI] [BOOTLOADER] Montar particiones:"; \
		sudo mount $${LOOP_DEV}p1 EFI/; \
		sudo mount $${LOOP_DEV}p2 ROOT/; \
		sudo mkdir -p EFI/EFI/BOOT/; \
		sleep 5; \
		sudo cp BOOTX64.EFI EFI/EFI/BOOT/ ; \
		sudo cp bootloader.efi EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

$(BOOTLOADER_ARTIFACT): $(BOOTLOADER)
	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -s -f ../chapter3/edk2 edk2

	@mkdir -p edk2/$(CHAPTER)Pkg/bootloader
	@cp -f bootloader.c edk2/$(CHAPTER)Pkg/bootloader/bootloader.c
	@cp -f bootloader.inf edk2/$(CHAPTER)Pkg/bootloader/bootloader.inf
	@cp -f bootloader.dsc edk2/$(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.

clean:
	@echo "[UEFI] [BOOTLOADER] Limpiando:"
	@echo
	@rm -f *.bin *.efi *.EFI *.elf $(DISK) $(DISK_NG) *.o *.so *.log
