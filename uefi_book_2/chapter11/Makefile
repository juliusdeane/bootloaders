SUDO := sudo
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
SBSIGN := sbsign
OPENSSL := openssl

DISK := disk.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384

DISK_MOK := disk_mok.img
DISK_MOK_SIZE := 1024
HASH_ALGORITHM := sha512
KEY_SIZE := 4096
KEY_LIVE_DAYS := 3650
KEY_NAME := chapter11_mok
KEY_COMMON_NAME := BootloaderChapter11_MOK
MOK_KEY := $(KEY_NAME).der

BOOTX64 := ../chapter10/bootx64.efi
TARGET_NAME := BOOTX64
TARGET := $(TARGET_NAME).efi


all: OVMF $(DISK) $(DISK_MOK) $(TARGET)
	@echo "[UEFI] [BOOT] Copiando recursos necesarios: BOOTX64.EFI"
	@$(SUDO) $(CP) bootx64.efi.signed DISK/EFI/BOOT/BOOTX64.EFI

	@echo "[UEFI] [BOOT] Copiando recursos necesarios: CRT/PEM/ESL/AUTH (no las KEYS)"
	@$(SUDO) $(CP) uefi_keys/*.pem DISK/keys/
	@$(SUDO) $(CP) uefi_keys/*.crt DISK/keys/
	@$(SUDO) $(CP) uefi_keys/*.esl DISK/keys/
	@$(SUDO) $(CP) uefi_keys/*.auth DISK/keys/

	@echo "[UEFI] [BOOT] Desmontar disco:"
	@$(SUDO) $(UMOUNT) -fq DISK


OVMF_CODE.fd OVMF_VARS.fd:
	@echo "Copiando $@ desde /usr/share/OVMF/"
	@cp /usr/share/OVMF/$@ .

OVMF: OVMF_CODE.fd OVMF_VARS.fd
	@echo "[UEFI] [BOOT] Copiando ficheros OVMF:"


$(TARGET):
	@echo "[UEFI] [BOOT] Copiando fichero EFI:"
	@$(CP) $(BOOTX64) $(TARGET).unsigned

	@echo "[UEFI] [BOOT] Firmando fichero EFI:"
	@$(SBSIGN) --key uefi_keys/DB4096.key --cert uefi_keys/DB4096.pem --output bootx64.efi.signed $(TARGET).unsigned


$(DISK):
	@echo "[UEFI] [$(DISK)] DISK Fabrik:"
	@$(DD) if=/dev/zero of=$(DISK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_SIZE)
# Vamos a usar el disco entero para FAT32.
	@$(SUDO) $(PARTED) $(DISK) mklabel gpt
	@$(SUDO) $(PARTED) $(DISK) mkpart primary fat32 1MiB 100%
	@$(SUDO) $(PARTED) $(DISK) set 1 esp on

# Asegurar EFI/:
	@$(MKDIR) -p DISK/

# Sistema de archivos y directorios:
	@$(SUDO) $(MKFS_VFAT) -F32 $(DISK)
	@$(SUDO) $(MOUNT) $(DISK) DISK/
	@$(SUDO) $(MKDIR) -p DISK/EFI/BOOT
	@$(SUDO) $(MKDIR) -p DISK/keys


$(DISK_MOK): $(MOK_KEY)
	@echo "[UEFI] [$(DISK_MOK)] DISK Fabrik:"
	@$(DD) if=/dev/zero of=$(DISK_MOK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_MOK_SIZE)
# Vamos a usar el disco entero para FAT32.
	@$(SUDO) $(PARTED) $(DISK) mklabel gpt
	@$(SUDO) $(PARTED) $(DISK) mkpart primary fat32 1MiB 100%
	@$(SUDO) $(PARTED) $(DISK) set 1 esp on

# Asegurar EFI/:
	@$(MKDIR) -p DISK_MOK/

# Sistema de archivos y directorios: sin contenido real EFI, solamente la clave MOK.der
	@$(SUDO) $(MKFS_VFAT) -F32 $(DISK_MOK)
	@$(SUDO) $(MOUNT) $(DISK_MOK) DISK_MOK/
	@$(SUDO) $(MKDIR) -p DISK_MOK/EFI/BOOT
	@$(SUDO) $(MKDIR) -p DISK_MOK/keys
	@echo "[UEFI] [$(DISK_MOK)] MOK KEY copy to disk:"
	@$(SUDO) $(CP) $(MOK_KEY) DISK_MOK/keys
	@echo "[UEFI] [$(DISK_MOK)] umount and finish (within QEMU):"
	@$(SUDO) $(UMOUNT) DISK_MOK/

$(MOK_KEY):
	@echo "[UEFI] [$(DISK_MOK)] MOK KEY Fabrik:"
	@$(OPENSSL) req -new -batch -x509 -nodes -utf8 -$(HASH_ALGORITHM) \
		-newkey rsa:$(KEY_SIZE) \
		-days $(KEY_LIVE_DAYS) \
		-keyout $(KEY_NAME).secret -outform DER -out $(MOK_KEY) \
		-subj "/CN=$(KEY_COMMON_NAME)/"

clean:
	@echo "[UEFI] [$(DISK)] Limpiando:"
	@$(RM) -f $(DISK) *.unsigned *.efi *.signed *.log
	@$(RM) -rf DISK/ DISK_MOK/
	@echo

hard_clean: clean
	@echo "[UEFI] [$(DISK)] Limpiando los OVMG:"
	@$(RM) -f OVMF_*.fd
	@echo
