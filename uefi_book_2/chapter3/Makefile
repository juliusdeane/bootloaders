ASM := nasm
FASM := fasm
CC := gcc
MINGW := x86_64-w64-mingw32-gcc
LD := ld
DD := dd
CP := cp
OBJCOPY := objcopy
MKFS_VFAT := mkfs.vfat
MKFS_EXT4 := mkfs.ext4

PARTED := parted
LOSETUP := losetup
PYTHON3 := venv/bin/python3

BOOTLOADER_V0 := bootloader_v0.asm
BOOTLOADER_V0_ARTIFACT := bootloader_v0.efi

BOOTLOADER_V0_C := bootloader_v0.c
BOOTLOADER_V0_C_O := bootloader_v0_c.o
BOOTLOADER_V0_C_ARTIFACT := bootloader_v0_c.efi

BOOTLOADER_V0_2_C := bootloader_v0_2.c
BOOTLOADER_V0_2_C_O := bootloader_v0_2_c.o
BOOTLOADER_V0_2_C_ARTIFACT := bootloader_v0_2_c.efi

BOOTLOADER_V0_3_C := bootloader_v0_3.c
BOOTLOADER_V0_3_C_O := bootloader_v0_3_c.o
BOOTLOADER_V0_3_C_ARTIFACT := bootloader_v0_3_c.efi

# IMPORTANTE la extensión cpp.
BOOTLOADER_V1_C := bootloader_v1.cpp
BOOTLOADER_V1_C_ARTIFACT := bootloader_v1_c.efi
# IMPORTANTE la extensión cpp.
BOOTLOADER_V1_C_2 := bootloader_v1_2.cpp
BOOTLOADER_V1_C_2_ARTIFACT := bootloader_v1_c_2.efi

BOOTLOADER_V1 := bootloader_v1.asm
BOOTLOADER_V1_ARTIFACT := bootloader_v1.efi

BOOTLOADER_V2 := bootloader_v2.asm
BOOTLOADER_V2_ARTIFACT := bootloader_v2.efi

BOOTLOADER_V3 := bootloader_v3.asm
BOOTLOADER_V3_ARTIFACT := bootloader_lief.bin

# Vamos a tener que darle una vuelta a cómo vamos a gestionar
# el WORKSPACE y nuestros Makefile :-?
EDK2_HOLAMUNDO := edk2/Build/MdeModule/DEBUG_GCC5/X64/HolaMundo.efi
EDK2_HOLAMUNDO2 := edk2/Build/MdeModule/DEBUG_GCC5/X64/HolaMundo2.efi
EDK2_BOOTMANAGER := edk2/Build/MdeModule/DEBUG_GCC5/X64/BootManagerMenuApp.efi

DISK := disk.img
DISK_NG := disk_ng.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384

##############################################################################
# Recursos EFI particulares
# - de: https://stackoverflow.com/questions/31514866/how-to-compile-uefi-application-using-gnu-efi
##############################################################################
# Esto lo eliminaremos a futuro porque usaremos siempre x86_64
ARCH            = $(shell uname -m | sed s,i[3456789]86,ia32,)
EFIINC          = /usr/include/efi
# Aquí hay algún include que no teníamos contemplado :-?
EFIINCS         = -I$(EFIINC) -I$(EFIINC)/$(ARCH) -I$(EFIINC)/protocol
# En nuestro sistema está en /lib (no en lib64).
LIB             = /lib
EFI_CRT_OBJS    = $(LIB)/crt0-efi-$(ARCH).o
EFI_LDS         = $(LIB)/elf_$(ARCH)_efi.lds
CFLAGS          = $(EFIINCS) -ffreestanding -fpic \
                             -fno-stack-check -fno-stack-protector \
                             -fshort-wchar -mno-red-zone -maccumulate-outgoing-args \
                             -Wall
# De nuevo, como usaremos siempre x86_64 esto desaparecerá:
ifeq ($(ARCH),x86_64)
  CFLAGS += -DEFI_FUNCTION_WRAPPER
endif

LDFLAGS         = -shared -Bsymbolic -nostdlib \
                  -T $(EFI_LDS) \
                  -L $(LIB) $(EFI_CRT_OBJS) \
                  -lgnuefi -lefi
##############################################################################
# //FIN: Recursos EFI particulares
##############################################################################

all: clean $(BOOTLOADER_V0_C_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] BOOT.EFI Fabrik:"
	@echo

# Ya no vamos a usar los artefactos ASM, pero lo genero para poder contrastar
# con objdump y otras herramientas.
	@echo "[UEFI] [BOOTLOADER_V0/ASM] Compilar: $(BOOTLOADER_V0)"
	@$(FASM) $(BOOTLOADER_V0) $(BOOTLOADER_V0_ARTIFACT)

# Quita el comentario para usar el v0 ASM:
#	@$(CP) $(BOOTLOADER_V0_ARTIFACT) BOOTX64.EFI
# Comenta la línea siguiente para usar el artefacto ASM y no el C:
	@$(CP) $(BOOTLOADER_V0_C_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_V0_C_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

# Este bloque será eliminado a futuro:
# - es para ilustrar gnu-efi en el capítulo 3.
test_gnuefi: clean $(BOOTLOADER_V0_C_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_GNU_EFI] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(BOOTLOADER_V0_C_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_V0_C_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

# Este bloque será eliminado a futuro:
# - es para ilustrar MingW en el capítulo 3.
test_morris: clean $(BOOTLOADER_V1_C_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_MINGW] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(BOOTLOADER_V1_C_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_V1_C_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo


# Este bloque será eliminado a futuro:
# - es para ilustrar EDK II en el capítulo 3.
test_edk2: clean
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_EDK2] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(EDK2_HOLAMUNDO) EDK_0.EFI
	@$(CP) $(EDK2_BOOTMANAGER) BOOTX64_EDK.EFI

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
		sudo cp BOOTX64_EDK.EFI EFI/EFI/BOOT/BOOTX64.EFI ; \
		sudo cp EDK_0.EFI EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

# Este bloque será eliminado a futuro:
# - es para ilustrar gnu-efi en el capítulo 3.
test_gnuefi2: clean $(BOOTLOADER_V0_2_C_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_GNU_EFI/SIN RETURN] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(BOOTLOADER_V0_2_C_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_V0_2_C_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

# Este bloque será eliminado a futuro:
# - es para ilustrar gnu-efi en el capítulo 3.
test_gnuefi3: clean $(BOOTLOADER_V0_3_C_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_GNU_EFI/BUCLE INFINITO] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(BOOTLOADER_V0_3_C_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_V0_3_C_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

# Este bloque será eliminado a futuro:
# - es para ilustrar MingW en el capítulo 3.
test_morris2: clean $(BOOTLOADER_V1_C_2_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_MINGW/BUCLE INFINITO] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(BOOTLOADER_V1_C_2_ARTIFACT) BOOTX64.EFI

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
		sudo cp $(BOOTLOADER_V1_C_2_ARTIFACT) EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo


# ORIGINAL: no funciona (hay que comentarlo al final del capítulo 3):
# TEST_GNU_EFI:
$(BOOTLOADER_V0_C_ARTIFACT): $(BOOTLOADER_V0_C)
	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C:"
	@$(CC) -I/usr/include/efi/ -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar \
           -mno-red-zone -maccumulate-outgoing-args -c $(BOOTLOADER_V0_C) -o $(BOOTLOADER_V0_C_O)
	@$(LD) -shared -Bsymbolic -L/usr/lib/ -L/usr/lib32/ \
                   -T/usr/lib/elf_x86_64_efi.lds /usr/lib/crt0-efi-x86_64.o \
                   $(BOOTLOADER_V0_C_O) -o $(BOOTLOADER_V0_C_O).so -lgnuefi -lefi
	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                $(BOOTLOADER_V0_C_O).so $(BOOTLOADER_V0_C_ARTIFACT)

# TEST_MORRIS:
$(BOOTLOADER_V1_C_ARTIFACT): $(BOOTLOADER_V1_C)
	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C con MingW:"
	@$(MINGW) -mno-red-zone \
              -DEFI_FUNCTION_WRAPPER \
              -ffreestanding \
              -fshort-wchar -nostdlib \
              -e efi_main \
              -Wl,-dll -shared \
              -Wl,--subsystem,10 \
              -I/usr/include/efi \
              -c $(BOOTLOADER_V1_C) -o $(BOOTLOADER_V1_C_ARTIFACT)

# Tampoco funciona, pero por si quieres probar:
# - hay que quitarle los comentarios al final del capítulo 3.
#$(BOOTLOADER_V0_C_ARTIFACT):
#	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C:"
#	@$(CC) $(CFLAGS) -c $(BOOTLOADER_V0_C) -o $(BOOTLOADER_V0_C_O)
#	@$(LD) $(LDFLAGS) $(BOOTLOADER_V0_C_O) -o $(BOOTLOADER_V0_C_O).so
#	@$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym \
#			    -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc \
#			    --target=efi-app-$(ARCH) \
#			    --subsystem=10 \
#			    $(BOOTLOADER_V0_C_O).so $(BOOTLOADER_V0_C_ARTIFACT)

# TEST_GNU_EFI2:
$(BOOTLOADER_V0_2_C_ARTIFACT): $(BOOTLOADER_V0_2_C)
	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C (versión 2, sin return):"
	@$(CC) -I/usr/include/efi/ -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar \
           -mno-red-zone -maccumulate-outgoing-args -c $(BOOTLOADER_V0_2_C) -o $(BOOTLOADER_V0_2_C_O)
	@$(LD) -shared -Bsymbolic -L/usr/lib/ -L/usr/lib32/ \
                   -T/usr/lib/elf_x86_64_efi.lds /usr/lib/crt0-efi-x86_64.o \
                   $(BOOTLOADER_V0_2_C_O) -o $(BOOTLOADER_V0_2_C_O).so -lgnuefi -lefi
	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                $(BOOTLOADER_V0_2_C_O).so $(BOOTLOADER_V0_2_C_ARTIFACT)

# TEST_GNU_EFI3:
$(BOOTLOADER_V0_3_C_ARTIFACT): $(BOOTLOADER_V0_3_C)
	@echo "[UEFI] [BOOTLOADER] (C-version) Compilando C (versión 3, bucle infinito):"
	@$(CC) -I/usr/include/efi/ -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar \
           -mno-red-zone -maccumulate-outgoing-args -c $(BOOTLOADER_V0_3_C) -o $(BOOTLOADER_V0_3_C_O)
	@$(LD) -shared -Bsymbolic -L/usr/lib/ -L/usr/lib32/ \
                   -T/usr/lib/elf_x86_64_efi.lds /usr/lib/crt0-efi-x86_64.o \
                   $(BOOTLOADER_V0_3_C_O) -o $(BOOTLOADER_V0_3_C_O).so -lgnuefi -lefi
	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                $(BOOTLOADER_V0_3_C_O).so $(BOOTLOADER_V0_3_C_ARTIFACT)

# TEST_MORRIS2:
$(BOOTLOADER_V1_C_2_ARTIFACT): $(BOOTLOADER_V1_C_2)
	@echo "[UEFI] [BOOTLOADER] (C-version/bucle infinito) Compilando C con MingW:"
	@$(MINGW) -mno-red-zone \
              -DEFI_FUNCTION_WRAPPER \
              -ffreestanding \
              -fshort-wchar -nostdlib \
              -e efi_main \
              -Wl,-dll -shared \
              -Wl,--subsystem,10 \
              -I/usr/include/efi \
              -c $(BOOTLOADER_V1_C_2) -o $(BOOTLOADER_V1_C_2_ARTIFACT)

# Este bloque será eliminado a futuro:
# - es para ilustrar EDK II en el capítulo 3.
test_edk2_2: clean
	@echo
	@echo "[UEFI] [BOOTLOADER] [TEST_EDK2/BUCLE INFINITO] BOOT.EFI Fabrik:"
	@echo

	@$(CP) $(EDK2_HOLAMUNDO) EDK_0.EFI
	@$(CP) $(EDK2_HOLAMUNDO2) EDK_0_2.EFI
	@$(CP) EDK_0_2.EFI BOOTX64_EDK.EFI
	@$(CP) $(EDK2_BOOTMANAGER) BOOTMANAGER.EFI

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
		sudo cp EDK_0_2.EFI EFI/EFI/BOOT/BOOTX64.EFI ; \
		sudo cp EDK_0.EFI EFI/EFI/BOOT/ ; \
		sudo cp EDK_0_2.EFI EFI/EFI/BOOT/ ; \
		sudo cp BOOTMANAGER.EFI EFI/EFI/BOOT/ ; \
		echo "[UEFI] [BOOTLOADER] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo umount ROOT/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] [BOOTLOADER] <completado>"; \
		echo

clean:
	@echo "[UEFI] [BOOTLOADER] Limpiando:"
	@echo
	@rm -f *.bin *.efi *.EFI *.elf $(DISK) $(DISK_NG) *.o *.so *.log
