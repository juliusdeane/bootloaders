CC := gcc
LD := ld
CP := cp
OBJCOPY := objcopy

ARCH            =  x86_64
EFIINC          = /usr/include/efi
EFIINCS         = -I$(EFIINC)
LIB             = /usr/lib
LIB32           = /usr/lib32
EFI_CRT_OBJS    = /usr/lib/crt0-efi-x86_64.o
EFI_LDS         = /usr/lib/elf_x86_64_efi.lds
CFLAGS          = $(EFIINCS) -DEFI_FUNCTION_WRAPPER \
                             -ffreestanding -fpic \
                             -fno-stack-check -fno-stack-protector \
                             -fshort-wchar -mno-red-zone -maccumulate-outgoing-args \
                             -Wall


ip.efi: ip.c clean
	@echo "[UEFI] [IP] (C-version/gnu-efi) Compilando C:"

	@$(CC) $(CFLAGS) -c ip.c -o ip.o

	@echo "[UEFI] [IP] (C-version/gnu-efi) Linker  .o  => .so:"
	@$(LD) -shared -Bsymbolic -L$(LIB) -L$(LIB) \
                   -T$(EFI_LDS) $(EFI_CRT_OBJS) \
                   ip.o -o ip.so -lgnuefi -lefi

	@echo "[UEFI] [IP] (C-version/gnu-efi) objcopy .so => PE32+: ip.efi"
	@$(OBJCOPY) -j .text -j .sdata -j .data -j .rodata -j .dynamic -j .dynsym \
                -j .rel -j .rela -j .rel.* -j .rela.* -j .reloc --target efi-app-x86_64 --subsystem=10 \
                ip.so ip.efi
	@echo "[UEFI] [IP] Terminado."
	@echo

clean:
	@echo "[UEFI] [IP] (C-version/gnu-efi) Limpiando recursos:"
	@rm -f *.o *.so *.efi
