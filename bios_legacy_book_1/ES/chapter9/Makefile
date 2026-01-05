ASM := /usr/bin/nasm
CC := /usr/bin/x86_64-linux-gnu-gcc
RUSTUP := ~/.cargo/bin/rustup
CARGO := ~/.cargo/bin/cargo
RUSTC := ~/.cargo/bin/rustc
OBJCOPY := /usr/bin/x86_64-linux-gnu-objcopy
EMU := /usr/bin/qemu-system-x86_64
EMU386 := /usr/bin/qemu-system-i386
DD := /usr/bin/dd
BS := 512

DISK := disk.img
DISK_RUST := disk_rust.img

# KERNEL.c a .bin:
CFLAGS = -m64 -ffreestanding -fno-stack-protector -fno-builtin \
         -nostdlib -nostartfiles -nodefaultlibs -fno-pie -Os \
         -Wall -Wextra
# LINKER Flags
LDFLAGS = -m elf_x86_64 -nostdlib -T linker.ld

.PHONY: all clean test

all: $(DISK)

rust: $(DISK_RUST)

# COMPILAR stages (ASM)
stage1.bin: stage1.asm
	@echo "[STAGE1.ASM] Compilando:"
	@$(ASM) -f bin $< -o $@

stage2.bin: stage2_ng.asm
	@echo "[STAGE2_NG.ASM] Compilando:"
	@$(ASM) -f bin $< -o $@

stage3.bin: stage3_ng.asm
	@echo "[STAGE3_NG.ASM] Compilando:"
	@$(ASM) -f bin $< -o $@

stage3_rust.bin: stage3_rust.asm
	@echo "[STAGE3_RUST.ASM] Compilando:"
	@$(ASM) -f bin $< -o $@

# Compilar kernel (C)
kernel.o: kernel_ng.c
	@echo "[KERNEL_NG.C] Compilar:"
	@$(CC) $(CFLAGS) -c $< -o $@

# Enlazar kernel a ELF64 y convertir a binario
kernel.bin: kernel.o linker.ld
	@echo "[KERNEL] Enlazando..."
	@$(LD) $(LDFLAGS) kernel.o -o kernel.elf
	@echo "[KERNEL] Convirtiendo a binario..."
	@$(OBJCOPY) -O binary kernel.elf $@

# Compilar kernel (RUST)
kernel_rust.o: kernel.rs
	@$(RUSTUP) target add x86_64-unknown-none
	@echo "[KERNEL.RS] Compilar:"
	@$(RUSTC) --edition 2021 \
	          --crate-type staticlib \
	          --target x86_64-unknown-none \
	          -C opt-level=2 \
	          -C panic=abort \
	          --emit obj=$@ $<

# Enlazar kernel a ELF64 y convertir a binario
kernel_rust.bin: kernel_rust.o linker.ld
	@echo "[KERNEL] Enlazando..."
	@$(LD) $(LDFLAGS) kernel_rust.o -o kernel_rust.elf
	@echo "[KERNEL] Convirtiendo a binario..."
	@$(OBJCOPY) -O binary kernel_rust.elf $@

# BUILD disk image
$(DISK): stage1.bin stage2.bin stage3.bin kernel.bin
	@echo "[DISK.IMG] Build:"
	@$(DD) if=/dev/zero of=$@ bs=1024 count=1024 2>/dev/null
	@$(DD) if=stage1.bin of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage2.bin of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage3.bin of=$@ bs=512 seek=17 conv=notrunc 2>/dev/null
	@$(DD) if=kernel.bin of=$@ bs=512 seek=33 conv=notrunc 2>/dev/null

	@echo
	@echo "Imagen de disco creada: $@"

# BUILD RUST disk image
$(DISK_RUST): stage1.bin stage2.bin stage3_rust.bin kernel_rust.bin
	@echo "[DISK_RUST.IMG] Build:"
	@$(DD) if=/dev/zero of=$@ bs=1024 count=1024 2>/dev/null
	@$(DD) if=stage1.bin of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage2.bin of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
# Un entry point diferente en Rust, naturalmente.
	@$(DD) if=stage3_rust.bin of=$@ bs=512 seek=17 conv=notrunc 2>/dev/null
	@$(DD) if=kernel_rust.bin of=$@ bs=512 seek=33 conv=notrunc 2>/dev/null

	@echo
	@echo "Imagen de disco creada: $@"


# BUILD linker script
linker.ld:
	@echo "[STAGE3] [LINKER.LD] Create:"
	@echo "ENTRY(kernel_entry)" > $@
	@echo "SECTIONS {" >> $@
	@echo "  . = 0x300000;" >> $@
	@echo "  .text : { *(.text) }" >> $@
	@echo "  .rodata : { *(.rodata) }" >> $@
	@echo "  .data : { *(.data) }" >> $@
	@echo "  .bss : { *(.bss) }" >> $@
	@echo "}" >> $@

clean:
	@rm -f *.o *.bin *.elf linker.ld disk.img disk_rust.img