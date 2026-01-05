ASM := nasm
EMU := qemu-system-x86_64
DD := dd

DISK := disk_chapter3.img
DISK2 := disk2_chapter3.img
DISK3 := disk3_chapter3.img

DISK2_SECTORS := 17
WHOLE_DISK2_SECTORS := 18

# stage2_2 es muy pequeño.
DISK3_SECTORS := 1
WHOLE_DISK3_SECTORS := 2


all: disk
	@echo "[NASM] Compilando stage1:"
	@$(ASM) -f bin bootloader_stage1.asm -o stage1.bin

	@echo "[NASM] Compilando stage1_1:"
	@$(ASM) -f bin bootloader_stage1_1.asm -o stage1_1.bin

	# MBR para leer 1 sector de stage2
	@$(DD) if=stage1.bin of=$(DISK) bs=512 count=1 conv=notrunc
	# MBR para leer 17 sectores de stage2
	@$(DD) if=stage1_1.bin of=$(DISK2) bs=512 count=1 conv=notrunc
	# De nuevo MBR para leer 1 sector de stage2
	@$(DD) if=stage1.bin of=$(DISK3) bs=512 count=1 conv=notrunc

	@echo "[NASM] Compilando stage2 (v0):"
	@$(ASM) -f bin bootloader_stage2_0.asm -o stage2_0.bin
	@$(DD) if=stage2_0.bin of=$(DISK) bs=512 count=1 seek=1 conv=notrunc

	@echo "[NASM] Compilando stage2 (v1):"
	@$(ASM) -f bin bootloader_stage2_1.asm -o stage2_1.bin
	@$(DD) if=stage2_1.bin of=$(DISK2) bs=512 count=$(DISK2_SECTORS) seek=1 conv=notrunc

	@echo "[NASM] Compilando stage2 (v2):"
	@$(ASM) -f bin bootloader_stage2_2.asm -o stage2_2.bin
	@$(DD) if=stage2_2.bin of=$(DISK3) bs=512 count=$(DISK3_SECTORS) seek=1 conv=notrunc

disk:
	@$(DD) if=/dev/zero of=$(DISK) bs=512 count=2
	@$(DD) if=/dev/zero of=$(DISK2) bs=512 count=$(WHOLE_DISK2_SECTORS)
	@$(DD) if=/dev/zero of=$(DISK3) bs=512 count=$(WHOLE_DISK3_SECTORS)

clean:
	@echo "[CLEAN] Limpiando entorno:"
	@rm -f *.bin *.o *.elf disk*
	@echo

test:
	@echo "[QEMU] Arrancando el disco:"
	@$(EMU) -drive \
            file=$(DISK),format=raw,snapshot=on \
            -serial stdio
	@echo

test2:
	@echo "[QEMU] Arrancando el disco 2:"
	@$(EMU) -drive \
            file=$(DISK2),format=raw,snapshot=on \
            -serial stdio
	@echo

test3:
	@echo "[QEMU] Arrancando el disco 3:"
	@$(EMU) -drive \
            file=$(DISK3),format=raw,snapshot=on \
            -serial stdio
	@echo