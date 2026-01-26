DD := dd
CP := cp
MKFS_VFAT := mkfs.vfat
MKFS_EXT4 := mkfs.ext4

PARTED := parted
LOSETUP := losetup
PYTHON3 := venv/bin/python3

CHAPTER := Chapter7

INTERFACES_NAME := interfaces
INTERFACES := $(INTERFACES_NAME).c
INTERFACES_INF := $(INTERFACES_NAME).inf
INTERFACES_DSC := $(INTERFACES_NAME).dsc
INTERFACES_ARTIFACT := $(INTERFACES_NAME).efi
BUILT_INTERFACES_ARTIFACT := edk2/Build/$(INTERFACES_NAME)/DEBUG_GCC5/X64/$(INTERFACES_ARTIFACT)

IP_NAME := ip
IP := $(IP_NAME).c
IP_INF := $(IP_NAME).inf
IP_DSC := $(IP_NAME).dsc
IP_ARTIFACT := $(IP_NAME).efi
BUILT_IP_ARTIFACT := edk2/Build/$(IP_NAME)/DEBUG_GCC5/X64/$(IP_ARTIFACT)

PING_NAME := Ping
PING := $(PING_NAME).c
PING_INF := $(PING_NAME).inf
PING_DSC := $(PING_NAME).dsc
PING_ARTIFACT := $(PING_NAME).efi
BUILT_PING_ARTIFACT := edk2/Build/$(PING_NAME)/DEBUG_GCC5/X64/$(PING_ARTIFACT)

TCPTEST_NAME := TcpTest
TCPTEST := $(TCPTEST_NAME).c
TCPTEST_INF := $(TCPTEST_NAME).inf
TCPTEST_DSC := $(TCPTEST_NAME).dsc
TCPTEST_ARTIFACT := $(TCPTEST_NAME).efi
BUILT_TCPTEST_ARTIFACT := edk2/Build/$(TCPTEST_NAME)/DEBUG_GCC5/X64/$(TCPTEST_ARTIFACT)

HTTPTEST_NAME := HttpTest
HTTPTEST := $(HTTPTEST_NAME).c
HTTPTEST_INF := $(HTTPTEST_NAME).inf
HTTPTEST_DSC := $(HTTPTEST_NAME).dsc
HTTPTEST_ARTIFACT := $(HTTPTEST_NAME).efi
BUILT_HTTPTEST_ARTIFACT := edk2/Build/$(HTTPTEST_NAME)/DEBUG_GCC5/X64/$(HTTPTEST_ARTIFACT)


DISK := disk.img
DISK_BLOCK_SIZE := 1M
DISK_SIZE := 16384


all: clean $(INTERFACES_ARTIFACT) $(IP_ARTIFACT) $(PING_ARTIFACT) $(TCPTEST_ARTIFACT) $(HTTPTEST_ARTIFACT)
	@echo
	@echo "[UEFI] [BOOTLOADER] BOOTX64.EFI/EDK2 Fabrik:"
	@echo

# Por si acaso:
	@ln -s -f ../../../RESOURCES/ RESOURCES
	@mkdir -p EFI/

	@echo "[UEFI] [INTERFACES.EFI] Copiar $(INTERFACES_ARTIFACT):"
	@$(CP) $(BUILT_INTERFACES_ARTIFACT) $(INTERFACES_ARTIFACT)

	@echo "[UEFI] [IP.EFI] Copiar $(IP_ARTIFACT):"
	@$(CP) $(BUILT_IP_ARTIFACT) $(IP_ARTIFACT)

	@echo "[UEFI] [PING.EFI] Copiar $(PING_ARTIFACT):"
	@$(CP) $(BUILT_PING_ARTIFACT) $(PING_ARTIFACT)

	@echo "[UEFI] [TCPTEST.EFI] Copiar $(TCPTEST_ARTIFACT):"
	@$(CP) $(BUILT_TCPTEST_ARTIFACT) $(TCPTEST_ARTIFACT)

	@echo "[UEFI] [HTTPTEST.EFI] Copiar $(HTTPTEST_ARTIFACT):"
	@$(CP) $(BUILT_HTTPTEST_ARTIFACT) $(HTTPTEST_ARTIFACT)

	@echo "[UEFI] [BOOTLOADER] DISK Fabrik:"
	@$(DD) if=/dev/zero of=$(DISK) bs=$(DISK_BLOCK_SIZE) count=$(DISK_SIZE)

# Vamos a usar el disco entero para FAT32.
	@sudo $(PARTED) $(DISK) mklabel gpt
	@sudo $(PARTED) $(DISK) mkpart primary fat32 1MiB 100%
	@sudo $(PARTED) $(DISK) set 1 esp on

	@sudo $(LOSETUP) -fP $(DISK)
	@LOOP_DEV=$$($(LOSETUP) -a | grep $(DISK) | grep -v deleted | sed 's/:.*//'); \
		echo "[UEFI] Loop device: $$LOOP_DEV"; \
		sudo $(MKFS_VFAT) -F32 $${LOOP_DEV}p1; \
		echo "[UEFI] Montar particiones:"; \
		sudo mount $${LOOP_DEV}p1 EFI/; \
		sudo mkdir -p EFI/EFI/BOOT/; \
		sudo mkdir -p EFI/boot/; \
		sleep 5; \
		echo "[UEFI] Copiar aplicaciones EFI:"; \
		sudo cp interfaces.efi EFI/EFI/BOOT/ ; \
		sudo cp ip.efi EFI/EFI/BOOT/ ; \
		sudo cp Ping.efi EFI/EFI/BOOT/ ; \
		sudo cp TcpTest.efi EFI/EFI/BOOT/ ; \
		sudo cp HttpTest.efi EFI/EFI/BOOT/ ; \
		echo "[UEFI] Copiar KERNEL:"; \
		sudo cp RESOURCES/vmlinuz-6.8.0-86-generic EFI/boot/vmlinuz ; \
		echo "[UEFI] Copiar INITRD:"; \
		sudo cp RESOURCES/initrd.bootloader.cmp EFI/boot/initrd.cmp ; \
		echo "[UEFI] DES-montar particiones:"; \
		sudo umount EFI/; \
		sudo losetup -d $$LOOP_DEV; \
		echo "[UEFI] <completado>"; \
		echo

$(INTERFACES_ARTIFACT): $(INTERFACES)
	@echo "[UEFI] [INTERFACES] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -s -f ../chapter3/edk2 edk2

	@mkdir -p edk2/$(CHAPTER)Pkg/interfaces
	@cp -f interfaces.c edk2/$(CHAPTER)Pkg/interfaces/interfaces.c
	@cp -f interfaces.inf edk2/$(CHAPTER)Pkg/interfaces/interfaces.inf
	@cp -f interfaces.dsc edk2/$(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.


$(IP_ARTIFACT): $(IP)
	@echo "[UEFI] [IP] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -s -f ../chapter3/edk2 edk2

	@mkdir -p edk2/$(CHAPTER)Pkg/ip
	@cp -f ip.c edk2/$(CHAPTER)Pkg/ip/ip.c
	@cp -f ip.inf edk2/$(CHAPTER)Pkg/ip/ip.inf
	@cp -f ip.dsc edk2/$(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.


$(PING_ARTIFACT): $(PING)
	@echo "[UEFI] [PING] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -s -f ../chapter3/edk2 edk2

	@mkdir -p edk2/$(CHAPTER)Pkg/Ping
	@cp -f Ping.c edk2/$(CHAPTER)Pkg/Ping/Ping.c
	@cp -f Ping.inf edk2/$(CHAPTER)Pkg/Ping/Ping.inf
	@cp -f Ping.dsc edk2/$(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.


$(TCPTEST_ARTIFACT): $(TCPTEST)
	@echo "[UEFI] [TCPTEST] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -s -f ../chapter3/edk2 edk2

	@mkdir -p edk2/$(CHAPTER)Pkg/TcpTest
	@cp -f TcpTest.c edk2/$(CHAPTER)Pkg/TcpTest/TcpTest.c
	@cp -f TcpTest.inf edk2/$(CHAPTER)Pkg/TcpTest/TcpTest.inf
	@cp -f TcpTest.dsc edk2/$(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.


$(HTTPTEST_ARTIFACT): $(HTTPTEST)
	@echo "[UEFI] [HTTPTEST] (C-version) Compilando C/EDK2:"

# Por si acaso:
	@ln -s -f ../chapter3/edk2 edk2

	@mkdir -p edk2/$(CHAPTER)Pkg/HttpTest
	@cp -f HttpTest.c edk2/$(CHAPTER)Pkg/HttpTest/HttpTest.c
	@cp -f HttpTest.inf edk2/$(CHAPTER)Pkg/HttpTest/HttpTest.inf
	@cp -f HttpTest.dsc edk2/$(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc

# Activamos el entorno en edk2:
# BEGIN: al usar @abrimos un nuevo shell:
# - debemos continuar la ejecución dentro de este nuevo shell con \ y con ;
	@cd edk2/ && . ./edksetup.sh ; \
	build -a X64 -t GCC5 -p $(CHAPTER)Pkg/$(CHAPTER)Pkg.dsc
# //END: SALIMOS DEL NUEVO SHELL.


clean:
	@echo "[UEFI] [BOOTLOADER] Limpiando:"
	@echo
	@rm -f *.bin *.efi *.EFI *.elf $(DISK) $(DISK_NG) *.o *.so *.log rm edk2 RESOURCES
# Delete compiled interfaces
	@rm -rf edk2/Build/$(BOOTLOADER_NAME)
	@rm -rf edk2/Build/$(INTERFACES_NAME)
	@rm -rf edk2/Build/$(IP_NAME)
	@rm -rf edk2/Build/$(TCPTEST)
	@rm -rf EFI/
