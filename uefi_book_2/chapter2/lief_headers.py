#!/usr/bin/env python3
import os
import sys
import subprocess

import lief


DEBUG = os.getenv('DEBUG', False)
if DEBUG is not False:
    DEBUG = True

DO_ASSEMBLE = os.getenv('DO_ASSEMBLE', False)
if DO_ASSEMBLE is not False:
    DO_ASSEMBLE = True

NASM = os.getenv('NASM', 'nasm')


def print_debug(msg):
    if DEBUG is True:
        print(msg)


def assemble_bootloader(source_file='code.asm', target_file='code.bin'):
    print_debug(f"[NASM] Ensamblando {source_file}...")

    # Compilar el código ensamblador
    result = subprocess.run(
        [NASM, '-f', 'bin', source_file, '-o', target_file],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print_debug(f"Error al compilar: {result.stderr}")
        return False

    if not os.path.exists('code.bin'):
        print_debug("Error: code.bin no fue creado")
        return False

    print_debug(f"   ✓ code.bin creado ({os.path.getsize('code.bin')} bytes)")
    return True


def build_bootloader(bin_file='code.bin', target_file='BOOTX64.EFI'):
    print_debug("[LIEF] Creando estructura PE...")

    # Crear un PE desde cero: PE32 PLUS (PE32+).
    pe = lief.PE.Binary("BOOTX64", lief.PE.PE_TYPE.PE32_PLUS)

    # Configurar Optional Header
    pe.optional_header.subsystem = lief.PE.SUBSYSTEM.EFI_APPLICATION
    pe.optional_header.imagebase = 0x400000
    pe.optional_header.section_alignment = 0x1000
    pe.optional_header.file_alignment = 0x200
    pe.optional_header.major_operating_system_version = 0
    pe.optional_header.minor_operating_system_version = 0
    pe.optional_header.major_image_version = 1
    pe.optional_header.minor_image_version = 0
    pe.optional_header.major_subsystem_version = 0
    pe.optional_header.minor_subsystem_version = 0

    # Stack y Heap
    pe.optional_header.sizeof_stack_reserve = 0x200000
    pe.optional_header.sizeof_stack_commit = 0x1000
    pe.optional_header.sizeof_heap_reserve = 0x100000
    pe.optional_header.sizeof_heap_commit = 0x1000

    print_debug("[LIEF] Añadiendo sección .text...")

    # Leer el código compilado
    with open(bin_file, 'rb') as f:
        code_data = f.read()

    # Crear sección .text
    text_section = lief.PE.Section(".text")
    text_section.content = list(code_data)
    text_section.virtual_address = 0x1000

    # Características: CODE | EXECUTE | READ
    text_section.characteristics = (
            lief.PE.SECTION_CHARACTERISTICS.MEM_READ |
            lief.PE.SECTION_CHARACTERISTICS.MEM_EXECUTE |
            lief.PE.SECTION_CHARACTERISTICS.CNT_CODE
    )

    pe.add_section(text_section)

    # Configurar entry point (apunta al inicio de .text)
    pe.optional_header.addressof_entrypoint = 0x1000

    print_debug("[LIEF] Generando BOOTX64.EFI...")

    # Construir y guardar
    builder = lief.PE.Builder(pe)
    builder.build()
    builder.write(target_file)

    if not os.path.exists(target_file):
        print_debug("[LIEF] ✗ Error al crear BOOTX64.EFI")
        return False

    size = os.path.getsize(target_file)
    print_debug(f"[LIEF] ✓ BOOTX64.EFI creado ({size} bytes)")
    return True


def main(binary_file='code.bin', target_file='BOOTX64.EFI'):
    print_debug("=== EFI Bootloader Builder (LIEF) ===\n")

    # Verificar dependencias
    if not os.path.exists(binary_file):
        print_debug(f"Error: {binary_file} no encontrado")
        return -1

    if DO_ASSEMBLE is True:
        try:
            subprocess.run([NASM, '-v'], capture_output=True, check=True)
        except:  # noqa
            print_debug("Error: NASM no está instalado")
            print_debug("Instala con: sudo apt install nasm")
            return -2

    try:
        import lief
    except ImportError:
        print_debug("Error: LIEF no está instalado")
        print_debug("Instala con: pip install lief")
        return -3

    # Construir
    if not build_bootloader(bin_file=binary_file,
                            target_file=target_file):
        print_debug("\n[LIEF] [ERROR] ✗ Error en la generación")
        return -4

    print_debug("\n✓ Compilación exitosa!")
    return 0


if __name__ == "__main__":
    # Por defecto:
    bin_file = 'code.bin'
    argc = len(sys.argv)
    if argc == 2:
        bin_file = sys.argv[1]

    sys.exit(main(binary_file=bin_file))
