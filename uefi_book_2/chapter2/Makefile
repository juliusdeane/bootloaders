ASM := nasm
FASM := fasm
DD := dd
CP := cp
PARTED := parted
LOSETUP := losetup
PYTHON3 := venv/bin/python3

BOOTLOADER_V0 := bootloader_v0.asm
BOOTLOADER_V0_ARTIFACT := bootloader_v0.efi

BOOTLOADER_V1 := bootloader_v1.asm
BOOTLOADER_V1_ARTIFACT := bootloader_v1.efi

BOOTLOADER_V2 := bootloader_v2.asm
BOOTLOADER_V2_ARTIFACT := bootloader_v2.efi

BOOTLOADER_V3 := bootloader_v3.asm
BOOTLOADER_V3_ARTIFACT := bootloader_lief.bin

DISK := disk_ng.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384

all: clean
	@echo
	@echo "[UEFI] [BOOTLOADER] BOOT.EFI Fabrik:"
	@echo

	@echo "[UEFI] [BOOTLOADER_V0] Compilar: $(BOOTLOADER_V0)"
	@$(FASM) $(BOOTLOADER_V0) $(BOOTLOADER_V0_ARTIFACT)

	@echo "[UEFI] [BOOTLOADER_V1] Compilar: $(BOOTLOADER_V1)"
	@$(FASM) $(BOOTLOADER_V1) $(BOOTLOADER_V1_ARTIFACT)

	@echo "[UEFI] [BOOTLOADER_V2] Compilar: $(BOOTLOADER_V2)"
	@$(FASM) $(BOOTLOADER_V2) $(BOOTLOADER_V2_ARTIFACT)
# Mantenemos esta línea comentada para entrar en el shell UEFI:
#   => quita el comentario cuando quieras que arranque correctamente.
#	@$(CP) $(BOOTLOADER_V2_ARTIFACT) BOOTX64.EFI

	@echo "[UEFI] [BOOTLOADER_V3/LIEF] Compilar: $(BOOTLOADER_V3)"
	@$(ASM) -f bin $(BOOTLOADER_V3) -o $(BOOTLOADER_V3_ARTIFACT)

# Cabeceras PE32+ con un script en Python.
#@$(PYTHON3) lief_headers.py bootloader_lief.bin

	@echo "[UEFI] [BOOTLOADER] DISK Fabrik:"
	@$(DD) if=/dev/zero of=$(DISK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_SIZE)
	@sudo $(PARTED) $(DISK) mklabel gpt
	@sudo $(PARTED) $(DISK) mkpart primary fat32 1MiB 513MiB
	@sudo $(PARTED) $(DISK) set 1 esp on
	@sudo $(PARTED) $(DISK) mkpart primary ext4 513MiB 100%

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$(losetup -a | grep disk_ng.img | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] [BOOTLOADER] Loop device: $$LOOP_DEV"; \
		sudo mkfs.vfat -F32 $${LOOP_DEV}p1; \
		sudo mkfs.ext4 $${LOOP_DEV}p2; \
		echo "[UEFI] [BOOTLOADER] Montar particiones:"; \
		sudo mount $${LOOP_DEV}p1 EFI/; \
		sudo mount $${LOOP_DEV}p2 ROOT/; \
		sudo mkdir -p EFI/EFI/BOOT/; \
		sleep 5; \
		sudo cp bootloader_v0.efi EFI/EFI/BOOT/ ; \
		sudo cp bootloader_v0.efi EFI/EFI/BOOT/test0.exe ; \
		sudo cp bootloader_v1.efi EFI/EFI/BOOT/ ; \
		sudo cp bootloader_v1.efi EFI/EFI/BOOT/test1.exe ; \
		sudo cp BOOTX64.EFI EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo
clean:
	@rm -f *.bin *.efi *.elf $(DISK)
