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

# Flags para el compilador C
CFLAGS = -m64 -ffreestanding -fno-stack-protector -fno-builtin \
         -nostdlib -nostartfiles -nodefaultlibs -fno-pie -Os \
         -Wall -Wextra -mno-red-zone

# Flags para el linker
LDFLAGS = -m elf_x86_64 -nostdlib -T linker.ld

.PHONY: all clean run

all: $(DISK)

# Compilar stage1 (del proyecto original)
stage1.bin: stage1.asm
	@echo "[STAGE1] Compilando..."
	@$(ASM) -f bin $< -o $@

# Compilar stage2 (del proyecto original)
stage2.bin: stage2.asm
	@echo "[STAGE2] Compilando..."
	@$(ASM) -f bin $< -o $@

# Compilar stage3 NUEVO
stage3.bin: stage3.asm gdt64.asm globals.asm serial32.asm serial64.asm
	@echo "[STAGE3] Compilando..."
	@$(ASM) -f bin $< -o $@

# Compilar handlers de la IDT (ensamblador)
idt64_handlers.o: idt64_handlers.asm
	@echo "[IDT64_HANDLERS] Compilando..."
	@$(ASM) -f elf64 $< -o $@

# Compilar inicialización de la IDT (C)
idt64.o: idt64.c
	@echo "[IDT64] Compilando..."
	@$(CC) $(CFLAGS) -c $< -o $@

# Compilar kernel
kernel.o: kernel.c
	@echo "[KERNEL] Compilando..."
	@$(CC) $(CFLAGS) -c $< -o $@

# Enlazar kernel con IDT
kernel.bin: kernel.o idt64.o idt64_handlers.o linker.ld
	@echo "[KERNEL] Enlazando..."
	@$(LD) $(LDFLAGS) kernel.o idt64.o idt64_handlers.o -o kernel.elf
	@echo "[KERNEL] Convirtiendo a binario..."
	@$(OBJCOPY) -O binary kernel.elf $@

# Compilar programa de usuario (opcional)
userapp.bin: userapp.asm
	@echo "[USERAPP] Compilando..."
	@$(ASM) -f bin $< -o $@

# BUILD linker script
linker.ld:
	@echo "[STAGE3] [LINKER.LD] Create:"
	@echo "ENTRY(kernel_entry)" > $@
	@echo "SECTIONS {" >> $@
	@echo "  . = 0x300000;" >> $@
	@echo "  .text : {" >> $@
	@echo "    *(.text.entry)" >> $@
	@echo "    *(.text)" >> $@
	@echo "  }" >> $@
	@echo "  .rodata : { *(.rodata) }" >> $@
	@echo "  .data : { *(.data) }" >> $@
	@echo "  .bss : { *(.bss) }" >> $@
	@echo "  . = 0x600000;" >> $@
	@echo "  .usercode : { *(.usercode) }" >> $@
	@echo "}" >> $@

# Crear imagen de disco
$(DISK): stage1.bin stage2.bin stage3.bin kernel.bin userapp.bin
	@echo "[DISK] Creando imagen..."
	@$(DD) if=/dev/zero of=$@ bs=1024 count=2048 2>/dev/null
	@$(DD) if=stage1.bin of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage2.bin of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
	@$(DD) if=stage3.bin of=$@ bs=512 seek=17 conv=notrunc 2>/dev/null
	@$(DD) if=kernel.bin of=$@ bs=512 seek=33 conv=notrunc 2>/dev/null
	@$(DD) if=userapp.bin of=$@ bs=512 seek=49 conv=notrunc 2>/dev/null
	@echo
	@echo "========================================="
	@echo "Imagen de disco creada: $@"
	@echo "========================================="
	@echo "Stage1:  Sector 0"
	@echo "Stage2:  Sectores 1-16"
	@echo "Stage3:  Sectores 17-32"
	@echo "Kernel:  Sector 33+"
	@echo "UserApp: Sector 49"
	@echo "========================================="

clean:
	@echo "[CLEAN] Limpiando..."
	@rm -f *.o *.bin *.elf $(DISK) *.log
	@echo "Limpieza completa"
