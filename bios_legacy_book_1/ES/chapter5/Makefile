ASM := nasm
EMU := qemu-system-x86_64
EMU386 := qemu-system-i386
DD := dd
BS := 512

DISK_SECTORS := 3

KERNEL := vmlinuz-6.8.0-86-generic
DISK_KERNEL := disk_kernel_chapter5.img
DISK_KERNEL_TEST1 := disk_kernel_test1_chapter5.img
DISK_KERNEL_TEST2 := disk_kernel_test2_chapter5.img
DISK_KERNEL_TEST3 := disk_kernel_test3_chapter5.img
DISK_KERNEL_TEST4 := disk_kernel_test4_chapter5.img
# No es buena idea apurar al máximo de tamaño...
# Lo veremos en capítulos posteriores.
KERNEL_SECTORS := 29221
KERNEL_SIZE := 14961032
SIGNATURE_OFFSET := 14962568
SIGNATURE_OFFSET_DEADBEEF := 14962562
# No la vamos a usar realmente...
SIGNATURE_OFFSET_BEEFDEAD := 14962562

# 29221 + 1 (MBR) + 2 (STAGE2) + 1 extra para establecer la firma 0xdeadbeef
DISK_KERNEL_SECTORS := 29225
# 29224 * 512
DEADBEEF_SKIP := 14962562

all: disk deadbeef
	@echo "[NASM] Compilando stage1 (+kernel):"
	@$(ASM) -f bin bootloader_stage1_kernel.asm -o stage1_kernel.bin
	@$(DD) if=stage1_kernel.bin of=$(DISK_KERNEL) bs=$(BS) count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage1_kernel.bin of=$(DISK_KERNEL_TEST1) bs=$(BS) count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage1_kernel.bin of=$(DISK_KERNEL_TEST2) bs=$(BS) count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage1_kernel.bin of=$(DISK_KERNEL_TEST3) bs=$(BS) count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage1_kernel.bin of=$(DISK_KERNEL_TEST4) bs=$(BS) count=1 conv=notrunc 2>/dev/null

	@echo "[NASM] Compilando stage2 (+kernel):"
	@$(ASM) -f bin bootloader_stage2_kernel.asm -o stage2_kernel.bin

	@echo "[NASM] Compilando stage2_test1 (+kernel):"
	@$(ASM) -f bin bootloader_stage2_kernel_test1.asm -o stage2_kernel_test1.bin

	@echo "[NASM] Compilando stage2_test2 (+kernel):"
	@$(ASM) -f bin bootloader_stage2_kernel_test2.asm -o stage2_kernel_test2.bin

	@echo "[NASM] Compilando stage2_test3 (+kernel):"
	@$(ASM) -f bin bootloader_stage2_kernel_test3.asm -o stage2_kernel_test3.bin

	@echo "[NASM] Compilando stage2_test4 (+kernel):"
	@$(ASM) -f bin bootloader_stage2_kernel_test4.asm -o stage2_kernel_test4.bin

	@echo "[DD] Set stage2_kernel.bin on disk:"
	@$(DD) if=stage2_kernel.bin of=$(DISK_KERNEL) bs=$(BS) seek=1 conv=notrunc 2>/dev/null

	@echo "[DD] Set stage2_kernel_test1.bin on disk:"
	@$(DD) if=stage2_kernel_test1.bin of=$(DISK_KERNEL_TEST1) bs=$(BS) seek=1 conv=notrunc 2>/dev/null

	@echo "[DD] Set stage2_kernel_test2.bin on disk:"
	@$(DD) if=stage2_kernel_test2.bin of=$(DISK_KERNEL_TEST2) bs=$(BS) seek=1 conv=notrunc 2>/dev/null

	@echo "[DD] Set stage2_kernel_test3.bin on disk:"
	@$(DD) if=stage2_kernel_test3.bin of=$(DISK_KERNEL_TEST3) bs=$(BS) seek=1 conv=notrunc 2>/dev/null

	@echo "[DD] Set stage2_kernel_test4.bin on disk:"
	@$(DD) if=stage2_kernel_test4.bin of=$(DISK_KERNEL_TEST4) bs=$(BS) seek=1 conv=notrunc 2>/dev/null

	@echo "[DD] Set KERNEL on disk/s (all tests):"
	@$(DD) if=$(KERNEL) of=$(DISK_KERNEL) bs=$(BS) seek=3 conv=notrunc 2>/dev/null
	@$(DD) if=$(KERNEL) of=$(DISK_KERNEL_TEST1) bs=$(BS) seek=3 conv=notrunc 2>/dev/null
	@$(DD) if=$(KERNEL) of=$(DISK_KERNEL_TEST2) bs=$(BS) seek=3 conv=notrunc 2>/dev/null
	@$(DD) if=$(KERNEL) of=$(DISK_KERNEL_TEST3) bs=$(BS) seek=3 conv=notrunc 2>/dev/null
	@$(DD) if=$(KERNEL) of=$(DISK_KERNEL_TEST4) bs=$(BS) seek=3 conv=notrunc 2>/dev/null

	@echo "[DD] Set 0xdeadbeef on disk/s: at $(SIGNATURE_OFFSET_DEADBEEF)"
	@$(DD) if=deadbeef.bin of=$(DISK_KERNEL) bs=1 seek=$(SIGNATURE_OFFSET_DEADBEEF) conv=notrunc 2>/dev/null
	@$(DD) if=deadbeef.bin of=$(DISK_KERNEL_TEST1) bs=1 seek=$(SIGNATURE_OFFSET_DEADBEEF) conv=notrunc 2>/dev/null
	@$(DD) if=deadbeef.bin of=$(DISK_KERNEL_TEST2) bs=1 seek=$(SIGNATURE_OFFSET_DEADBEEF) conv=notrunc 2>/dev/null
	@$(DD) if=deadbeef.bin of=$(DISK_KERNEL_TEST3) bs=1 seek=$(SIGNATURE_OFFSET_DEADBEEF) conv=notrunc 2>/dev/null
	@$(DD) if=deadbeef.bin of=$(DISK_KERNEL_TEST4) bs=1 seek=$(SIGNATURE_OFFSET_DEADBEEF) conv=notrunc 2>/dev/null

disk:
	@echo "[DISK] Creando disco/s:"
	@$(DD) if=/dev/zero of=$(DISK_KERNEL) bs=$(BS) count=$(DISK_SECTORS)
	@$(DD) if=/dev/zero of=$(DISK_KERNEL_TEST1) bs=$(BS) count=$(DISK_SECTORS)
	@$(DD) if=/dev/zero of=$(DISK_KERNEL_TEST2) bs=$(BS) count=$(DISK_SECTORS)
	@$(DD) if=/dev/zero of=$(DISK_KERNEL_TEST3) bs=$(BS) count=$(DISK_SECTORS)
	@$(DD) if=/dev/zero of=$(DISK_KERNEL_TEST4) bs=$(BS) count=$(DISK_SECTORS)

deadbeef:
	@echo 'deadbeef' | xxd -r -p > deadbeef.bin

clean:
	@echo "[CLEAN] Limpiando entorno:"
	@rm -f *.bin *.o *.elf disk*.img
	@rm -rf bootloader-initrd/ @rm -rf bootloader-initrd/ initrd.*.gz
	@echo

test_kernel:
	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@$(EMU) -drive \
            file=$(DISK_KERNEL),format=raw,snapshot=on \
            -serial stdio
	@echo

kernel_test1:
	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@echo "       - salto a kernel en 0x1000000:"
	@$(EMU) -drive \
            file=$(DISK_KERNEL_TEST1),format=raw,snapshot=on \
            -serial stdio
	@echo

kernel_test2:
	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@echo "       - salto a kernel en 0x1000200:"
	@$(EMU) -drive \
            file=$(DISK_KERNEL_TEST2),format=raw,snapshot=on \
            -serial stdio
	@echo

kernel_test3:
	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@echo "       - salto a kernel en 0x1001000:"
	@$(EMU) -drive \
            file=$(DISK_KERNEL_TEST3),format=raw,snapshot=on \
            -serial stdio
	@echo

kernel_test4:
	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@echo "       - salto a kernel en 0x1001000:"
	@$(EMU) -drive \
            file=$(DISK_KERNEL_TEST4),format=raw,snapshot=on \
            -serial stdio
	@echo

kernel_test4_debug:
	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@echo "       - salto a kernel en 0x1001000:"
	@echo "       - DEBUG en 127.127.127.1:1234:"
	@$(EMU386) -drive \
            file=$(DISK_KERNEL_TEST4),format=raw,snapshot=on \
            -nographic \
            -gdb tcp:127.127.127.1:1234 -S
	@echo

test_kernel_debug:
	@echo "[OBJCOPY] Preparando ficheros .bin -> elf (gdb, r2):"
	@objcopy -I binary -O elf32-i386 -B i386 \
			   --change-section-address .data=0x7c00 \
			   stage1_kernel.bin stage1_kernel.elf

	@objcopy -I binary -O elf32-i386 -B i386 \
			   --change-section-address .data=0x7c00 \
			   stage2_kernel.bin stage2_kernel.elf

	@echo "[QEMU] Arrancando el disco (cargar kernel de 15M):"
	@$(EMU386) -drive \
            file=$(DISK_KERNEL),format=raw,snapshot=on \
            -serial stdio \
            -gdb tcp:127.127.127.1:1234 -S
	@echo
