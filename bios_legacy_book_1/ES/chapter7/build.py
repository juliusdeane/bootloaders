#!/usr/bin/env python3

import os
import sys
import math
import subprocess as sp


DEBUG = os.getenv("DEBUG", True)
if DEBUG is not True:
    DEBUG = False

SKIP_DISK = os.getenv("SKIP_DISK", False)
if SKIP_DISK is not False:
    SKIP_DISK = True

SKIP_INITRD_BUILD = os.getenv("SKIP_INITRD_BUILD", False)
if SKIP_INITRD_BUILD is not False:
    SKIP_INITRD_BUILD = True

QEMU = os.getenv("QEMU", "/usr/bin/qemu-system-x86_64")
QEMU386 = os.getenv("QEMU386", "/usr/bin/qemu-system-i386")
ASM = os.getenv("ASM", "/usr/bin/nasm")
DD = os.getenv("DD", "/usr/bin/dd")
EMU = os.getenv("EMU", "/usr/bin/qemu-system-x86_64")
EMU386 = os.getenv("DD", "/usr/bin/qemu-system-i386")
SH = os.getenv("SH", "/bin/sh")
RM = os.getenv("RM", "/bin/rm")
DISK_FILENAME = os.getenv("DISK_FILENAME", "disk.img")
BS = 512

STAGE1_ASM = "bootloader_stage1_pm.asm"
STAGE2_ASM = "bootloader_stage2_pm.asm"

STAGE1_ARTIFACT = "stage1.bin"
STAGE2_ARTIFACT = "stage2.bin"

STAGE2_SECTORS = os.getenv("STAGE2_SECTORS", 16)
if STAGE2_SECTORS != 16:
    try:
        STAGE2_SECTORS = int(STAGE2_SECTORS)
    except:  # noqa
        STAGE2_SECTORS = 16

INITRD_DIR_ARTIFACT = "bootloader-initrd/"
# INITRD_ARTIFACT = "initrd.bootloader.gz"
INITRD_ARTIFACT = "initrd.bootloader.cmp"
KERNEL = "vmlinuz-6.8.0-86-generic"

EXTRA_SECTORS_AT_END = os.getenv("EXTRA_SECTORS_AT_END", 800)
if EXTRA_SECTORS_AT_END != 800:
    try:
        EXTRA_SECTORS_AT_END = int(EXTRA_SECTORS_AT_END)
    except:  # noqa
        EXTRA_SECTORS_AT_END = 800


def print_debug(msg):
    if DEBUG:
        print(msg)


def file_size(filename):
    return os.stat(filename).st_size


def size_in_sectors(size):
    return math.ceil(size / BS)


def gen_hex(cadena):
    try:
        # La función int() toma la cadena y la base (16 para hexadecimal)
        valor_entero = int(cadena, 16)
    except ValueError:
        print(f"[ERROR]: '{cadena}' no es un valor hexadecimal válido.")
        return None

    return valor_entero


def do_clean():
    print_debug(f"[CAPÍTULO 6] Limpiando entorno:")
    prc = sp.run(
        [
            RM,
            "-rf",
            STAGE1_ARTIFACT, STAGE2_ARTIFACT,
            DISK_FILENAME,
            INITRD_ARTIFACT,
            INITRD_DIR_ARTIFACT
        ],
        capture_output=True,
        text=True
    )
    return prc.returncode, prc.stdout


def compile_asm(filename, artifact):
    print_debug(f"[CAPÍTULO 6] Compilando [{filename}] => [{artifact}]:")

    prc = sp.run(
        [
            ASM, "-f", "bin",
            filename,
            "-o", artifact
        ],
        capture_output=True,
        text=True
    )

    return prc.returncode, prc.stdout


def build_initrd(artifact):
    """
    Creamos el initrd invocando el script que fabricamos en el Capítulo 5.

    *MUY IMPORTANTE:* cpio. Al añadir información de metadatos basados en, por ejemplo,
    como la hora del último acceso (atime), la hora de la última modificación (mtime),
    y la hora de cambio de estado (ctime), sí o sí va a generar ficheros de TAMAÑO DIFERENTE
    AL CREAR EL INITRD. Esto impide tener un tamaño predecible fijo. Hay que CALCULARLO SIEMPRE Y
    calcular dónde vamos a ubicar los recursos que pondremos al final (la firma beefdead).

    :param artifact: El fichero initrd que crearemos.
    :return: Tupla con el código de error (prc.returncode) y el texto de stdout (prc.stdout).
    """
    print_debug(f"[CAPÍTULO 6] Construyendo initrd [{artifact}]:")
    prc = sp.run(
        [
            SH,
            "build_bootloader_initrd.sh"
        ],
        capture_output=True,
        text=True
    )
    return prc.returncode, prc.stdout


def build_initial_disk(filename, **kwargs):
    print_debug(f"[CAPÍTULO 6] Construyendo DISCO [{filename}]:")

    arguments = [
        DD,
        'if=/dev/zero',
        f"of={filename}"
    ]

    bs = kwargs.get("bs", 512)
    sectors = kwargs.get("sectors", 3)
    disk_total_size = kwargs.get("total_size", None)

    # Si no quieres este comportamiento, ponlo a cero.
    sectors += EXTRA_SECTORS_AT_END

    if disk_total_size is None:
        arguments.append(f"bs={bs}")
        arguments.append(f"count={sectors}")
    else:
        arguments.append("bs=1")
        arguments.append(f"count={disk_total_size}")

    prc = sp.run(
        arguments,
        capture_output=True,
        text=True
    )
    return prc.returncode, prc.stdout


def read_binary(filename):
    with open(filename, 'rb') as f:
        binary_data = f.read()
    return binary_data


def write_at(filename, binary_data, **kwargs):
    position_bytes = kwargs.get("position_bytes", None)
    sector = kwargs.get("sector", None)
    bs = kwargs.get("bs", BS)

    # Calcular posición final
    if position_bytes is not None:
        position = position_bytes
    elif sector is not None:
        position = sector * bs
    else:
        raise ValueError("[ERROR] Debe especificar position_bytes o sector, como mínimo.")

    # Escribir en la posición
    with open(filename, 'r+b') as f:
        f.seek(position)
        bytes_written = f.write(binary_data)

    return bytes_written


def add_signature(filename, signature, **kwargs):
    position_bytes = kwargs.get("position_bytes", None)
    sector = kwargs.get("sector", None)
    bs = kwargs.get("bs", BS)

    binary_signature = signature.to_bytes(4, byteorder='little')

    return write_at(filename=filename, binary_data=binary_signature,
                    position_bytes=position_bytes, bs=bs, sector=sector)


def rebuild_structure_asm(**kwargs):
    stage1_start_sector = kwargs.get("stage1_start_sector", 0)
    stage1_size_sectors = kwargs.get("stage1_size_sectors", 1)

    stage2_start_sector = kwargs.get("stage2_start_sector", 1)
    stage2_size_sectors = kwargs.get("stage2_size_sectors", 16)

    krnl_start_sector = kwargs.get("kernel_start_sector", 17)
    krnl_size_sectors = kwargs.get("kernel_size_sectors", 29620)

    intrd_start_sector = kwargs.get("initrd_start_sector", 29638)
    intrd_size_sectors = kwargs.get("initrd_size_sectors", 2149)
    intrd_size_bytes = kwargs.get("initrd_size_bytes", 0)

    structure_asm = f'''; THIS FILE MUST BE AUTOGENERATED BY boot.py: do not modify.
STAGE1_START_SECTOR   equ {stage1_start_sector}
STAGE1_SIZE_SECTORS   equ {stage1_size_sectors}

STAGE2_START_SECTOR   equ {stage2_start_sector}
STAGE2_SIZE_SECTORS   equ {stage2_size_sectors}

KERNEL_START_SECTOR   equ {krnl_start_sector}
KERNEL_SIZE_SECTORS   equ {krnl_size_sectors}

INITRD_START_SECTOR   equ {intrd_start_sector}
INITRD_SIZE_SECTORS   equ {intrd_size_sectors}
INITRD_SIZE_BYTES     equ {intrd_size_bytes}
'''

    print_debug(structure_asm)
    with open("structure.asm", "w") as OUT:
        OUT.write(structure_asm)


########################################################################################
# MAIN:
########################################################################################
if __name__ == '__main__':
    total_size = 0
    total_sectors = 0
    beefdead_offset = 0

    stage1_asm = STAGE1_ASM
    stage1_artifact = STAGE1_ARTIFACT

    stage2_asm = STAGE2_ASM
    stage2_artifact = STAGE2_ARTIFACT

    argc = len(sys.argv)
    if argc == 2:
        argument = sys.argv[1].lower()
        if argument == "clean":
            res, out = do_clean()
            if res != 0:
                print_debug("[ERROR] Limpiando entorno:")
                print_debug(out)
                sys.exit(-1)
            sys.exit(0)
        else:
            print_debug("[ERROR] Comando no reconocido.")
            sys.exit(-3)

    print_debug("[CAPÍTULO 6] Fabrik script:")
    print("")

    ########################################################################################
    # PASADA 1: COMPILACIÓN INICIAL PARA CALCULAR TAMAÑOS
    ########################################################################################
    print_debug("[PASADA 1] Compilación inicial para calcular tamaños...")
    print("")

    # Compilar stage1
    stage1_result, output = compile_asm(
        filename=stage1_asm,
        artifact=stage1_artifact
    )

    if stage1_result != 0:
        print_debug(f"[ERROR] Compilando [{stage1_asm}]:")
        print_debug(output)
        sys.exit(1)

    # Siempre.
    total_size = 512
    stage1_sectors = 1
    total_sectors = stage1_sectors
    print_debug(f"\t{stage1_artifact}: 512 bytes/1 sector.")

    print("")

    # Compilar stage2 (temporal, sin structure.asm correcto)
    stage2_result, output2 = compile_asm(
        filename=stage2_asm,
        artifact=stage2_artifact
    )

    if stage2_result != 0:
        print_debug(f"[ERROR] Compilando [{stage2_asm}]:")
        print_debug(output2)
        sys.exit(2)

    stage2_size = file_size(filename=stage2_artifact)
    total_size += stage2_size
    stage2_sectors = size_in_sectors(size=stage2_size)
    if STAGE2_SECTORS == stage2_sectors:
        print_debug(f"[!!] STAGE2 sectors iguales: {STAGE2_SECTORS}/{stage2_sectors}:")
    total_sectors += stage2_sectors
    print_debug(f"\t{stage2_artifact}: {stage2_size} bytes/{stage2_sectors} sectors.")

    print("")

    # Calcular tamaño del kernel
    print_debug("[CAPÍTULO 6] [KERNEL] Calcular tamaños:")
    kernel_size = file_size(filename=KERNEL)
    total_size += kernel_size

    kernel_sectors = size_in_sectors(size=kernel_size)
    total_sectors += kernel_sectors
    print_debug(f"\t{KERNEL}: {kernel_size} bytes/{kernel_sectors} sectors.")

    kernel_bin_len = kernel_size

    # Calcular el siguiente sector natural desde total_size
    next_natural_sector_position = total_size % BS
    if next_natural_sector_position == 0:
        next_natural_sector_position = total_size
    else:
        bytes_to_next_sector = BS - next_natural_sector_position
        next_natural_sector_position = total_size + bytes_to_next_sector

    print("")
    # Construir initrd
    if SKIP_INITRD_BUILD is False:
        initrd_result, output3 = build_initrd(artifact=INITRD_ARTIFACT)
        if initrd_result != 0:
            print_debug("[ERROR] Creando [initrd.bootloader.gz]:")
            print_debug(output3)
            sys.exit(3)
    else:
        print("[***] INITRD no recreado (SKIP_INITRD_BUILD=True).")
        print("")

    initrd_size = file_size(filename=INITRD_ARTIFACT)
    initrd_sectors = size_in_sectors(size=initrd_size)
    print_debug(f"\t{INITRD_ARTIFACT}: {initrd_size} bytes/{initrd_sectors} sectors.")

    total_size += initrd_size
    total_sectors += initrd_sectors

    # Calcular posiciones
    kernel_start_sector = STAGE2_SECTORS + 1

    initrd_position = next_natural_sector_position
    initrd_start_sector = initrd_position // BS

    print("")
    print_debug(f"[POSICIONES CALCULADAS]:")
    print_debug(f"  kernel_start_sector: {kernel_start_sector}")
    print_debug(f"  kernel_sectors: {kernel_sectors}")
    print_debug(f"  initrd_start_sector: {initrd_start_sector}")
    print_debug(f"  initrd_position: {initrd_position}/{hex(initrd_position)}")
    print_debug(f"  initrd_sectors: {initrd_sectors}")

    ########################################################################################
    # GENERAR structure.asm CON LOS VALORES CORRECTOS
    ########################################################################################
    print("")
    print_debug("[GENERANDO structure.asm con valores calculados...]")
    rebuild_structure_asm(
        stage1_start_sector=0,
        stage1_sectors=1,
        stage2_start_sector=1,
        stage2_sectors=stage2_sectors,
        kernel_start_sector=kernel_start_sector,
        kernel_size_sectors=kernel_sectors,
        initrd_start_sector=initrd_start_sector,
        initrd_size_sectors=initrd_sectors,
        initrd_size_bytes=initrd_size
    )

    ########################################################################################
    # PASADA 2: RECOMPILAR STAGE2 CON structure.asm CORRECTO
    ########################################################################################
    print("")
    print_debug("[PASADA 2] Recompilando stage2 con structure.asm correcto...")

    stage2_result, output2 = compile_asm(
        filename=stage2_asm,
        artifact=stage2_artifact
    )

    if stage2_result != 0:
        print_debug(f"[ERROR] Recompilando [{stage2_asm}]:")
        print_debug(output2)
        sys.exit(2)

    # Verificar que el tamaño no cambió
    stage2_size_final = file_size(filename=stage2_artifact)
    if stage2_size_final != stage2_size:
        print_debug(f"[ADVERTENCIA] Stage2 cambió de tamaño: {stage2_size} -> {stage2_size_final}")
        print_debug(f"[ADVERTENCIA] Esto puede causar problemas. Considera ajustar STAGE2_SECTORS.")

    print_debug(f"[OK] Stage2 recompilado: {stage2_size_final} bytes")
    print("")

    # Leer binarios finales
    stage1_bin = read_binary(filename=stage1_artifact)
    stage2_bin = read_binary(filename=stage2_artifact)
    kernel_bin = read_binary(filename=KERNEL)
    initrd_bin = read_binary(filename=INITRD_ARTIFACT)

    ########################################################################################
    # CONSTRUIR DISCO CON LOS BINARIOS FINALES
    ########################################################################################
    disk_result, output4 = build_initial_disk(
        filename=DISK_FILENAME,
        bs=BS,
        sectors=total_sectors
    )
    if disk_result != 0:
        print_debug(f"[ERROR] Creando [{DISK_FILENAME}]:")
        print_debug(output4)
        sys.exit(4)

    # Escribir stage1
    stage1_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=stage1_bin,
        position_bytes=0
    )
    if stage1_write_result == 0:
        print_debug(f"[ERROR] Grabando stage1 en: [{DISK_FILENAME}]:")
        sys.exit(5)
    print_debug(f"[OK] Grabados [{stage1_write_result}] bytes de stage1 en: [{DISK_FILENAME}]:")

    # Escribir stage2
    stage2_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=stage2_bin,
        bs=BS,
        sector=1
    )
    if stage2_write_result == 0:
        print_debug(f"[ERROR] Grabando stage2 en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{stage2_write_result}] bytes de stage2 en: [{DISK_FILENAME}]:")

    # Escribir kernel
    print_debug(f"[!] Preparado para grabar [{kernel_bin_len}] bytes de KERNEL en: [{DISK_FILENAME}]:")
    kernel_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=kernel_bin,
        bs=BS,
        sector=kernel_start_sector
    )
    if kernel_write_result == 0:
        print_debug(f"[ERROR] Grabando KERNEL en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{kernel_write_result}] bytes de KERNEL en: [{DISK_FILENAME}]:")

    # Escribir initrd
    print("")
    print_debug(f"[OK] Iniciando grabación de INITRD en: [{DISK_FILENAME}]:")
    initrd_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=initrd_bin,
        bs=BS,
        position_bytes=initrd_position
    )

    if initrd_write_result == 0:
        print_debug(f"[ERROR] Grabando INITRD en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{initrd_write_result}] bytes de INITRD en: [{DISK_FILENAME}]:")

    signature_position = initrd_position + initrd_write_result + 8  # 8 bytes offset.

    # Cerrar initrd con firmas:
    add_signature(filename=DISK_FILENAME,
                  signature=0x44444444,
                  position_bytes=signature_position, bs=BS)

    add_signature(filename=DISK_FILENAME,
                  signature=0x43434343,
                  position_bytes=signature_position+4, bs=BS)

    add_signature(filename=DISK_FILENAME,
                  signature=0x42424242,
                  position_bytes=signature_position+8, bs=BS)

    add_signature(filename=DISK_FILENAME,
                  signature=0x41414141,
                  position_bytes=signature_position+12, bs=BS)

    print("")
    print_debug(f"[POSICIONES FINALES] (en sectores):")
    print_debug("[stage1] => 0")
    print_debug("[stage2] => 1")
    print_debug(f"[kernel] => {kernel_start_sector}")
    print_debug(f"[initrd] => {initrd_start_sector}")
    print_debug("--- END ---")

    print("")
    print_debug(f"[POSICIONES FINALES] (en bytes):")
    print_debug("[stage1] => 0")
    print_debug("[stage2] => 512")
    print_debug(f"[kernel] => {kernel_start_sector * BS}")
    print_debug(f"[initrd] => {initrd_position}/{hex(initrd_position)}")
    print_debug("--- END ---")

    print("")
    print_debug("[CAPÍTULO 6] [OK] Todo completado.")
    sys.exit(0)
