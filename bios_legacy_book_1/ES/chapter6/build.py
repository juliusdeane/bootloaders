#!/usr/bin/env python3

import os
import sys
import math
import subprocess as sp


DEBUG = os.getenv("DEBUG", True)
if DEBUG is not True:
    DEBUG = False

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

KERNEL_TO_DEADBEEF_PADDING = 8
DEADBEEF_TO_INITRD_PADDING = 12
INITRD_TO_BEEFDEAD_PADDING = 8

STAGE1_ASM = "bootloader_stage1.asm"
STAGE2_ASM = "bootloader_stage2.asm"
STAGE2_SEGMENTS_ASM = "bootloader_stage2_segments.asm"
STAGE2_SEGMENTS_AMS = "bootloader_stage2_cmdline.asm"
STAGE2_CMDLINE_ASM = "bootloader_stage2_cmdline.asm"
STAGE2_CMDLINE_V2_ASM = "bootloader_stage2_cmdline_v2.asm"
STAGE2_LOADFLAGS_ASM = "bootloader_stage2_loadflags.asm"
STAGE2_LOADFLAGS_V2_ASM = "bootloader_stage2_loadflags_v2.asm"
STAGE2_MORE_SECTORS_ASM = "bootloader_stage2_more_sectors.asm"

# NG: stage1 debe cargar 16 sectores ahora.
STAGE1_NG_ASM = "bootloader_stage1_ng.asm"
# Este stage2 es de 16 sectores (8192 bytes)
STAGE2_NG_ASM = "bootloader_stage2_ng.asm"

STAGE1_OPTION_B_ASM = "bootloader_stage1_optionb.asm"
# Opción B - este stage2 es de 16 sectores (8192 bytes)
STAGE2_OPTION_B_ASM = "bootloader_stage2_optionb.asm"

STAGE1_ARTIFACT = "stage1.bin"
STAGE2_ARTIFACT = "stage2.bin"
STAGE2_SEGMENTS_ARTIFACT = "stage2_segments.bin"
STAGE2_CMDLINE_ARTIFACT = "stage2_cmdline.bin"
STAGE2_CMDLINE_V2_ARTIFACT = "stage2_cmdline_v2.bin"
STAGE2_LOADFLAGS_ARTIFACT = "stage2_loadflags.bin"
STAGE2_LOADFLAGS_V2_ARTIFACT = "stage2_loadflags_v2.bin"
STAGE2_MORE_SECTORS_ARTIFACT = "stage2_more_sectors.bin"
# NG: stage1 debe cargar 16 sectores ahora.
STAGE1_NG_ARTIFACT = "stage1_ng.bin"
# Este stage2 es de 16 sectores (8192 bytes)
STAGE2_NG_ARTIFACT = "stage2_ng.bin"

STAGE1_OPTION_B_ARTIFACT = "stage1_optionb.bin"
# Opción B - este stage2 es de 16 sectores (8192 bytes)
STAGE2_OPTION_B_ARTIFACT = "stage2_optionb.bin"

STAGE2_SECTORS = os.getenv("STAGE2_SECTORS", 8)
if STAGE2_SECTORS != 8:
    try:
        STAGE2_SECTORS = int(STAGE2_SECTORS)
    except:  # noqa
        STAGE2_SECTORS = 8

# Sectores iniciales 4608 + tamaño del kernel. 14961032
# +8 bytes de margen a 0.
# (8 sectores)  0x00e45b90
# (16 sectores) 0x00e46b90
DEADBEEF_SIGNATURE_FIXED_POSITION = 14965648

# 0x00e45ba0
INITRD_FIXED_POSITION = 14965664
INITRD_NG_FIXED_POSITION = 14969760

INITRD_DIR_ARTIFACT = "bootloader-initrd/"
# INITRD_ARTIFACT = "initrd.bootloader.gz"
INITRD_ARTIFACT = "initrd.bootloader.cmp"
KERNEL = "vmlinuz-6.8.0-86-generic"


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
            STAGE2_SEGMENTS_ARTIFACT, STAGE2_SEGMENTS_ARTIFACT,
            STAGE2_CMDLINE_ARTIFACT, STAGE2_CMDLINE_V2_ARTIFACT,
            STAGE2_LOADFLAGS_ARTIFACT, STAGE2_LOADFLAGS_V2_ARTIFACT,
            STAGE2_MORE_SECTORS_ARTIFACT,
            STAGE1_NG_ARTIFACT, STAGE2_NG_ARTIFACT,
            STAGE1_OPTION_B_ARTIFACT, STAGE2_OPTION_B_ARTIFACT,
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


def add_deadbeef_signature(filename, position_bytes=DEADBEEF_SIGNATURE_FIXED_POSITION):
    """
    *MUY IMPORTANTE*: dado que initrd no va a ocupar siempre lo mismo por cómo se
    comporta cpio/gzip, SIEMPRE debemos recalcular el tamaño y no aceptar el tamaño
    por defecto que hemos puesto para position_bytes.

    En este caso, no es relevante porque el kernel que usamos es fijo y conocemos su
    tamaño exacto, por lo que la firma "0xdeadbeef" siempre va a estar en el mismo sitio.

    El problema real es con add_beefdead_signature().

    :param filename: El fichero del disco donde escribimos.
    :param position_bytes: El offset, en bytes, donde colocamos la firma.
    :return: Entero con el número de bytes escritos.
    """
    return add_signature(filename=filename, signature=0xdeadbeef,
                         position_bytes=position_bytes, bs=BS)


def add_beefdead_signature(filename, position_bytes):
    """
    *MUY IMPORTANTE*: dado que initrd no va a ocupar siempre lo mismo por cómo se
    comporta cpio/gzip, SIEMPRE debemos recalcular el tamaño y no aceptar el tamaño
    por defecto que hemos puesto para position_bytes.

    ES CRÍTICO en esta función calcular la posición de la firma. Por eso el parámetro
    position_bytes NO es opcional, ni tiene un valor por defecto.

    :param filename: El fichero del disco donde escribimos.
    :param position_bytes: El offset, en bytes, donde colocamos la firma.
    :return: Entero con el número de bytes escritos.
    """
    return add_signature(filename=filename, signature=0xbeefdead,
                         position_bytes=position_bytes, bs=BS)


def run(qemu_executable=QEMU, **kwargs):
    # qemu-system-x86_64 -drive file=disk.img,format=raw,snapshot=on -serial stdio
    print_debug(f"[CAPÍTULO 6] QEMU: [{qemu_executable}]:")

    arguments = [
        qemu_executable,
        '-drive',
        'file=disk.img,format=raw,snapshot=on'
    ]

    serial = kwargs.get("serial", False)
    nographic = kwargs.get("nographic", False)
    debug = kwargs.get("debug", False)

    if debug is True:
        print_debug(f"    -debug")
        nographic = False

        # -gdb tcp:127.127.127.1:1234 -S
        arguments.append('-gdb')
        arguments.append('tcp:127.127.127.1:1234')
        arguments.append('-S')

    if serial and nographic:
        print("[ERROR] Puede especificar serial o nographic, pero no ambas.")
        sys.exit(-9)

    if serial is True:
        print_debug(f"    -serial stdio")
        arguments.append('-serial')
        arguments.append('stdio')

    if nographic is True:
        print_debug(f"    -nographic")
        arguments.append('-nographic')

    prc = sp.run(
        arguments,
        capture_output=True,
        text=True
    )
    return prc.returncode, prc.stdout


def run_serial(qemu_executable=QEMU):
    return run(qemu_executable=qemu_executable, serial=True)


def run_nographic(qemu_executable=QEMU):
    return run(qemu_executable=qemu_executable, nographic=True)
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
        elif argument == "run":
            res, out = run_serial()
            if res != 0:
                print_debug("[ERROR] Ejecutando:")
                print_debug(out)
                sys.exit(-2)
            sys.exit(0)
        elif argument == "run_nographic":
            res, out = run_nographic()
            if res != 0:
                print_debug("[ERROR] Ejecutando:")
                print_debug(out)
                sys.exit(-2)
            sys.exit(0)
        elif argument == "run_debug":
            res, out = run(serial=True, debug=True)
            if res != 0:
                print_debug("[ERROR] Ejecutando DEBUG: [target remote 127.127.127.1:1234]")
                print_debug(out)
                sys.exit(-2)
            sys.exit(0)
        elif argument == "segments":
            # Esta versión ha cambiado los segmentos y los tiene correctos, aparentemente.
            stage2_asm = STAGE2_SEGMENTS_ASM
            stage2_artifact = STAGE2_SEGMENTS_ARTIFACT
        elif argument == "cmdline":
            # Esta versión ha cambiado la ubicación de la cmdline.
            stage2_asm = STAGE2_CMDLINE_ASM
            stage2_artifact = STAGE2_CMDLINE_ARTIFACT
        elif argument == "cmdline_v2":
            stage2_asm = STAGE2_CMDLINE_V2_ASM
            stage2_artifact = STAGE2_CMDLINE_V2_ARTIFACT
        elif argument == "loadflags":
            stage2_asm = STAGE2_LOADFLAGS_ASM
            stage2_artifact = STAGE2_LOADFLAGS_ARTIFACT
        elif argument == "loadflags_v2":
            stage2_asm = STAGE2_LOADFLAGS_V2_ASM
            stage2_artifact = STAGE2_LOADFLAGS_V2_ARTIFACT
        elif argument == "more_sectors":
            stage2_asm = STAGE2_MORE_SECTORS_ASM
            stage2_artifact = STAGE2_MORE_SECTORS_ARTIFACT
        elif argument == "ng":
            stage1_asm = STAGE1_NG_ASM
            stage1_artifact = STAGE1_NG_ARTIFACT

            stage2_asm = STAGE2_NG_ASM
            stage2_artifact = STAGE2_NG_ARTIFACT
            # 8192 bytes
            STAGE2_SECTORS = 16
        elif argument == "optionb":
            stage1_asm = STAGE1_OPTION_B_ASM
            stage1_artifact = STAGE1_OPTION_B_ARTIFACT

            stage2_asm = STAGE2_OPTION_B_ASM
            stage2_artifact = STAGE2_OPTION_B_ARTIFACT
            # 8192 bytes
            STAGE2_SECTORS = 16
        else:
            print_debug("[ERROR] Comando no reconocido.")
            sys.exit(-3)

    # Recalculamos por si hay nuevo número de sectores.
    # STAGE2_SIZE = STAGE2_SECTORS * BS

    print_debug("[CAPÍTULO 6] Fabrik script:")

    print_debug("[CAPÍTULO 6] Compilar =>")
    print("")

    stage1_result, output = compile_asm(
        filename=stage1_asm,
        artifact=stage1_artifact
    )

    if stage1_result != 0:
        print_debug(f"[ERROR] Compilando [{stage1_asm}]:")
        print_debug(output)
        sys.exit(1)

    stage1_size = file_size(filename=stage1_artifact)
    # +TOTAL_SIZE
    total_size += stage1_size
    stage1_sectors = size_in_sectors(size=stage1_size)
    total_sectors += stage1_sectors
    print_debug(f"\t{stage1_artifact}: {stage1_size} bytes/{stage1_sectors} sectors.")

    stage1_bin = read_binary(filename=stage1_artifact)

    print("")

    stage2_result, output2 = compile_asm(
        filename=stage2_asm,
        artifact=stage2_artifact
    )

    if stage2_result != 0:
        print_debug(f"[ERROR] Compilando [{stage2_asm}]:")
        print_debug(output2)
        sys.exit(2)

    stage2_size = file_size(filename=stage2_artifact)
    # +TOTAL_SIZE
    total_size += stage2_size
    stage2_sectors = size_in_sectors(size=stage2_size)
    if STAGE2_SECTORS == stage2_sectors:
        print_debug(f"[!!] STAGE2 sectors iguales: {STAGE2_SECTORS}/{stage2_sectors}:")
    total_sectors += stage2_sectors
    print_debug(f"\t{stage2_artifact}: {stage2_size} bytes/{stage2_sectors} sectors.")

    stage2_bin = read_binary(filename=stage2_artifact)

    print("")

    print_debug("[CAPÍTULO 6] [KERNEL] Calcular tamaños:")
    kernel_size = file_size(filename=KERNEL)
    # +TOTAL_SIZE
    total_size += kernel_size
    kernel_sectors = size_in_sectors(size=kernel_size)
    total_sectors += kernel_sectors
    print_debug(f"\t{KERNEL}: {kernel_size} bytes/{kernel_sectors} sectors.")

    kernel_bin = read_binary(filename=KERNEL)
    kernel_bin_len = len(kernel_bin)

    print("")

    initrd_result, output3 = build_initrd(artifact=INITRD_ARTIFACT)
    if initrd_result != 0:
        print_debug("[ERROR] Creando [initrd.bootloader.gz]:")
        print_debug(output3)
        sys.exit(3)

    initrd_size = file_size(filename=INITRD_ARTIFACT)
    initrd_sectors = size_in_sectors(size=initrd_size)
    print_debug(f"\t{INITRD_ARTIFACT}: {initrd_size} bytes/{initrd_sectors} sectors.")

    initrd_bin = read_binary(filename=INITRD_ARTIFACT)
    initrd_bin_len = len(initrd_bin)

    # +TOTAL_SIZE
    total_size += initrd_size
    total_sectors += initrd_sectors

    print("")
    if DEBUG is True:
        print("============ STATS: ============")
        print("   Total sectors:      %d" % total_sectors)
        print("   Total size (bytes): %d" % total_size)
        print("   +4 sectors extra (+2048 bytes)")
        print("================================")
        print("")

    # RECUERDA Añadir firma: 0xbeefdead y 0xdeadbeef.
    # AÑADIMOS 4 SECTORES extra para tener espacio al final del disco.
    total_sectors += 4
    total_size += 2048  # 4 x 512

    if DEBUG is True:
        print("========== NEW STATS: ==========")
        print("   Total sectors:      %d" % total_sectors)
        print("   Total size (bytes): %d" % total_size)
        print("================================")
        print("")

    # Generar disco con el tamaño adecuado.
    disk_result, output4 = build_initial_disk(filename=DISK_FILENAME,
                                              bs=BS, sectors=total_sectors)
    if disk_result != 0:
        print_debug(f"[ERROR] Creando [{DISK_FILENAME}]:")
        print_debug(output4)
        sys.exit(4)

    # Ahora escribir por partes cada bloque:
    stage1_write_result = write_at(filename=DISK_FILENAME,
                                   binary_data=stage1_bin, position_bytes=0)
    if stage1_write_result == 0:
        print_debug(f"[ERROR] Grabando stage1 en: [{DISK_FILENAME}]:")
        sys.exit(5)
    print_debug(f"[OK] Grabando [{stage1_write_result}] bytes de stage1 en: [{DISK_FILENAME}]:")

    stage2_write_result = write_at(filename=DISK_FILENAME,
                                   binary_data=stage2_bin, bs=BS, sector=1)
    if stage2_write_result == 0:
        print_debug(f"[ERROR] Grabando stage2 en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabando [{stage2_write_result}] bytes de stage2 en: [{DISK_FILENAME}]:")

    # Kernel debe empezar en 0x00001200 (sector 9).
    kernel_start_sector = STAGE2_SECTORS + 1
    print_debug(f"[!] Preparado para grabar [{kernel_bin_len}] bytes de KERNEL en: [{DISK_FILENAME}]:")
    kernel_write_result = write_at(filename=DISK_FILENAME,
                                   binary_data=kernel_bin, bs=BS, sector=kernel_start_sector)
    if kernel_write_result == 0:
        print_debug(f"[ERROR] Grabando KERNEL en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{kernel_write_result}] bytes de KERNEL en: [{DISK_FILENAME}]:")
    if kernel_bin_len == kernel_write_result:
        print_debug(f"    [OK] GRABADOS LOS MISMOS BYTES DE KERNEL ESTIMADOS [CORRECTO]")
    else:
        print_debug(f"    [AVISO] NO HEMOS GRABADO LOS MISMOS BYTES DE KERNEL ESTIMADOS [¿ERROR?]")

    stages_size = kernel_start_sector * BS
    kernel_plus_stages_size = kernel_write_result + stages_size
    kernel_plus_stages_sectors = kernel_plus_stages_size/BS

    # Sumamos 8 bytes de margen.
    deadbeef_position = kernel_plus_stages_size + KERNEL_TO_DEADBEEF_PADDING
    # Con stage2 8 sectores:  00e45b90  ef be ad de 00 00 00 00  00 00 00 00 00 00 00 00
    # Con stage2 16 sectores: 00e46b90  ef be ad de 00 00 00 00  00 00 00 00 00 00 00 00

    # 0xdeadbeef
    print("")
    deadbeef_result = add_deadbeef_signature(filename=DISK_FILENAME, position_bytes=deadbeef_position)
    if deadbeef_result == 0:
        print_debug(f"[ERROR] Grabando 0xdeadbeef en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabando [{deadbeef_result}] bytes de 0xdeadbeef en: [{DISK_FILENAME}]:")

    # initrd: +4 bytes de deadbeef, +DEADBEEF_TO_INITRD_PADDING bytes de margen.
    initrd_position = deadbeef_position + 4 + DEADBEEF_TO_INITRD_PADDING
    # Con stage2 8 sectores:  00e45ba0  1f 8b 08 00 00 00 00 00  00 03 ec 3a 0d 78 54 45
    # Con stage2 16 sectores: 00e46ba0  1f 8b 08 00 00 00 00 00  00 03 ec 3a 0d 74 93 55

    print("")
    # Bloque de inicio de initrd: initrd_position
    print_debug(f"[OK] Iniciando grabación de INITRD en: [{DISK_FILENAME}]:")
    initrd_write_result = write_at(filename=DISK_FILENAME,
                                   binary_data=initrd_bin, bs=BS, position_bytes=initrd_position)
    if initrd_write_result == 0:
        print_debug(f"[ERROR] Grabando INITRD en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{initrd_write_result}] bytes de INITRD en: [{DISK_FILENAME}]:")

    if initrd_bin_len == initrd_write_result:
        print_debug(f"    [OK] GRABADOS LOS MISMOS BYTES DE INITRD ESTIMADOS [CORRECTO]")
    else:
        print_debug(f"    [AVISO] NO HEMOS GRABADO LOS MISMOS BYTES DE INITRD ESTIMADOS [¿ERROR?]")

    # beefdead
    beefdead_position = initrd_position + INITRD_TO_BEEFDEAD_PADDING + initrd_write_result
    beefdead_result = add_beefdead_signature(filename=DISK_FILENAME, position_bytes=beefdead_position)

    if beefdead_result == 0:
        print_debug(f"[ERROR] Grabando 0xbeefdead en: [{DISK_FILENAME}] (pos: {beefdead_position} bytes):")
        sys.exit(6)
    print_debug(f"[OK] Grabando [{beefdead_result}] bytes de 0xbeefdead en: [{DISK_FILENAME}]:")

    print("")
    print_debug(f"[POSICIONES] Ahora mismo (en sectores):")
    print_debug("[stage1] => 0")
    print_debug("[stage2] => 1")
    print_debug(f"[kernel] => {kernel_start_sector}")
    print_debug(f"-[dbeef] -")
    print_debug(f"[initrd] => ?")
    print_debug(f"-[beefd] -")
    print_debug("--- END (use) ---")

    print("")
    print_debug(f"[POSICIONES] Ahora mismo (en bytes):")
    print_debug("[stage1] => 0")
    print_debug("[stage2] => 512")
    print_debug(f"[kernel] => {kernel_start_sector * BS}/{stages_size}")
    print_debug(f"-[dbeef] => {deadbeef_position}")
    print_debug(f"[initrd] => {initrd_position}")
    print_debug(f"-[beefd] => {beefdead_position}")
    print_debug("--- END (use) ---")

    print("")
    print_debug("[CAPÍTULO 6] [OK] Todo completado.")
    sys.exit(0)
