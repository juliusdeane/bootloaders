ASM := nasm
FASM := fasm
CC := gcc
LD := ld
DD := dd
CP := cp
OBJCOPY := objcopy
MKFS_VFAT := mkfs.vfat
MKFS_EXT4 := mkfs.ext4

PARTED := parted
LOSETUP := losetup
PYTHON3 := venv/bin/python3

BOOTLOADER := bootloader.c
BOOTLOADER_O := bootloader.o
BOOTLOADER_ARTIFACT := bootloader.efi

DISK := disk.img
DISK_NG := disk_ng.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384

##############################################################################
# Recursos EFI particulares
# - de: https://stackoverflow.com/questions/31514866/how-to-compile-uefi-application-using-gnu-efi
##############################################################################
ARCH            =  x86_64
EFIINC          = /usr/include/efi
# Aquí hay algún include que no teníamos contemplado :-?
EFIINCS         = -I$(EFIINC)
# En nuestro sistema está en /lib (no en lib64).
LIB             = /usr/lib
LIB32           = /usr/lib32
EFI_CRT_OBJS    = /usr/lib/crt0-efi-x86_64.o
EFI_LDS         = /usr/lib/elf_x86_64_efi.lds
CFLAGS          = $(EFIINCS) -DEFI_FUNCTION_WRAPPER \
                             -ffreestanding -fpic \
                             -fno-stack-check -fno-stack-protector \
                             -fshort-wchar -mno-red-zone -maccumulate-outgoing-args \
                             -Wall
##############################################################################
# //FIN: Recursos EFI particulares
##############################################################################

all: clean $(BOOTLOADER_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] BOOTX64.EFI/Kernel/Initrd Fabrik:"
	@echo

# Por si acaso:
	@mkdir -p EFI/
	@mkdir -p BOOT/
	@mkdir -p ROOT/

	@$(CP) $(BOOTLOADER_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

$(BOOTLOADER_ARTIFACT): $(BOOTLOADER)
	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C:"

	@$(CC) $(CFLAGS) -c $(BOOTLOADER) -o $(BOOTLOADER_O)

	@$(LD) -shared -Bsymbolic -L$(LIB) -L$(LIB) \
                   -T$(EFI_LDS) $(EFI_CRT_OBJS) \
                   $(BOOTLOADER_O) -o $(BOOTLOADER_O).so -lgnuefi -lefi

	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                $(BOOTLOADER_O).so $(BOOTLOADER_ARTIFACT)

clean:
	@echo "[UEFI] [BOOTLOADER] Limpiando:"
	@echo
	@rm -f *.bin *.efi *.EFI *.elf $(DISK) $(DISK_NG) *.o *.so *.log
