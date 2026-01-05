ASM := nasm
EMU := qemu-system-x86_64
EMU386 := qemu-system-i386
DD := dd
BS := 512

DISK := disk_chapter4.img
DISK_SECTORS := 3

all: disk
	@echo "[!!] Proceso para MODO IRREAL (UNREAL):"
	@echo
	@echo "[NASM] Compilando bootloader_unreal_simple:"
	@$(ASM) -f bin bootloader_unreal_simple.asm -o bootloader_unreal_simple.bin

	@echo "[NASM] Compilando stage1:"
	@$(ASM) -f bin bootloader_stage1.asm -o stage1.bin

	# MBR para leer 1 sector de stage2/stage2_kernel
	@$(DD) if=stage1.bin of=$(DISK) bs=$(BS) count=1 conv=notrunc

	@echo "[NASM] Compilando stage2:"
	@$(ASM) -f bin bootloader_stage2.asm -o stage2.bin
	@$(DD) if=stage2.bin of=$(DISK) bs=$(BS) count=2 seek=1 conv=notrunc

disk:
	@$(DD) if=/dev/zero of=$(DISK) bs=$(BS) count=$(DISK_SECTORS)

clean:
	@echo "[CLEAN] Limpiando entorno:"
	@rm -f *.bin *.o *.elf disk*.img
	@echo

test_simple:
	@echo "[QEMU] Arrancando el BIN simple:"
	@$(EMU386) bootloader_unreal_simple.bin -serial stdio
	@echo

test_simple_debug:
	@echo "[QEMU] Arrancando el BIN simple (DEBUG):"
	@$(EMU386) bootloader_unreal_simple.bin -serial stdio -gdb tcp:127.127.127.1:1234 -S
	@echo

test:
	@echo "[QEMU] Arrancando el disco:"
	@$(EMU) -drive \
            file=$(DISK),format=raw,snapshot=on \
            -serial stdio
	@echo

test_debug:
	@echo "[QEMU] Arrancando el disco (DEBUG):"
	@$(EMU) -drive \
            file=$(DISK),format=raw,snapshot=on \
            -serial stdio \
            -gdb tcp:127.127.127.1:1234 -S
	@echo
