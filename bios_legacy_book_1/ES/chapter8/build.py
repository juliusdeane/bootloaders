#!/usr/bin/env python3

import os
import sys
import math
import subprocess as sp


DEBUG = os.getenv("DEBUG", True)
if DEBUG is not True:
    DEBUG = False

CHAPTER_NUMBER = 8

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

STAGE1_ASM = "stage1.asm"
STAGE2_ASM = "stage2.asm"

STAGE1_ARTIFACT = "stage1.bin"
STAGE2_ARTIFACT = "stage2.bin"

INITRD_DIR_ARTIFACT = "bootloader-initrd/"
# INITRD_ARTIFACT = "initrd.bootloader.gz"
INITRD_ARTIFACT = "initrd.bootloader.cmp"
KERNEL = "vmlinuz-6.8.0-86-generic"

EXTRA_SECTORS_AT_END = os.getenv("EXTRA_SECTORS_AT_END", 8192)
if EXTRA_SECTORS_AT_END != 8192:
    try:
        EXTRA_SECTORS_AT_END = int(EXTRA_SECTORS_AT_END)
    except:  # noqa
        EXTRA_SECTORS_AT_END = 8192


def print_debug(msg: str):
    """
    Solamente imprime el texto si la variable DEBUG es True.

    :param msg: El texto a imprimir.
    :return: Nada.
    """
    if DEBUG is True:
        print(msg)


def file_size(filename: str) -> int:
    """
    Obtiene el valor del tamaño de un archivo en bytes (st_size).
    :param filename: El nombre del fichero en cadena de texto.
    :return: La cantidad de bytes del fichero (tamaño).
    """
    return os.stat(filename).st_size


def size_in_sectors(size: int) -> int:
    """
    Convertimos un tamaño en unidades de bytes en sectores (dividir por BS, 512).

    Para ser prudentes, lo redondeamos siempre hacia arriba.

    :param size: Un valor de bytes.
    :return: Un número de sectores de tamaño BS.
    """
    return math.ceil(size / BS)


def gen_hex(cadena: str) -> int|None:
    """
    Genera un valor entero hexadecimal a partir de una cadena de texto que representa el valor hexadecimal.
    :param cadena: El número hexadecimal en cadena de texto.
    :return: El valor entero o None, si ha habido errores de conversión.
    """
    try:
        # La función int() toma la cadena y la base (16 para hexadecimal)
        valor_entero = int(cadena, 16)
    except ValueError:
        print(f"[ERROR]: '{cadena}' no es un valor hexadecimal válido.")
        return None

    return valor_entero


def do_clean():
    """
    Limpia los recursos generados por build.

    :return: Una tupla con el código de status de la ejecución con run y el texto de la salida estándar.
    """
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Limpiando entorno:")
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


def compile_asm(filename: str, artifact: str):
    """
    Compila un .asm con la herramienta determinada en la variable ASM (nasm, por ejemplo).

    :param filename: El fichero ASM de entrada.
    :param artifact: El artefacto (.bin) de salida.
    :return: Una tupla con el código de status de la ejecución con run y el texto de la salida estándar.
    """
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Compilando [{filename}] => [{artifact}]:")

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


def build_initrd(artifact: str):
    """
    Creamos el initrd invocando el script que fabricamos en el Capítulo 5.

    *MUY IMPORTANTE:* cpio. Al añadir información de metadatos basados en, por ejemplo,
    como la hora del último acceso (atime), la hora de la última modificación (mtime),
    y la hora de cambio de estado (ctime), sí o sí va a generar ficheros de TAMAÑO DIFERENTE
    AL CREAR EL INITRD. Esto impide tener un tamaño predecible fijo. Hay que CALCULARLO SIEMPRE Y
    calcular dónde vamos a ubicar los recursos que pondremos al final (la firma beefdead).

    :param artifact: El nombre del fichero initrd que crearemos.
    :return: Tupla con el código de error (prc.returncode) y el texto de stdout (prc.stdout).
    """
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Construyendo initrd [{artifact}]:")
    print_debug(f"                          * pedirá elevar a root (por mknod):")
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
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Construyendo DISCO [{filename}]:")

    arguments = [
        DD,
        'if=/dev/zero',
        f"of={filename}"
    ]

    bs = kwargs.get("bs", 512)
    sectors = kwargs.get("sectors", 3)
    disk_total_size = kwargs.get("total_size", None)

    # Si no quieres este comportamiento, ponlo a cero.
    if EXTRA_SECTORS_AT_END > 0:
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


def read_binary(filename: str):
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
    stage2_size_bytes = kwargs.get("stage2_size_bytes", 0)

    krnl_start_sector = kwargs.get("kernel_start_sector", 17)
    krnl_size_sectors = kwargs.get("kernel_size_sectors", 29620)
    krnl_size_bytes = kwargs.get("kernel_size_bytes", 0)

    intrd_start_sector = kwargs.get("initrd_start_sector", 29638)
    intrd_size_sectors = kwargs.get("initrd_size_sectors", 2149)
    intrd_size_bytes = kwargs.get("initrd_size_bytes", 0)

    structure_asm = f'''; THIS FILE MUST BE AUTOGENERATED BY boot.py: do not modify.
STAGE1_START_SECTOR   equ {stage1_start_sector}
STAGE1_SIZE_SECTORS   equ {stage1_size_sectors}

STAGE2_START_SECTOR   equ {stage2_start_sector}
STAGE2_SIZE_SECTORS   equ {stage2_size_sectors}
STAGE2_SIZE_BYTES     equ {stage2_size_bytes}

KERNEL_START_SECTOR   equ {krnl_start_sector}
KERNEL_SIZE_SECTORS   equ {krnl_size_sectors}
KERNEL_SIZE_BYTES     equ {krnl_size_bytes}

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

    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Fabrik script:")
    print_debug("")

    ########################################################################################
    # PASADA 1: COMPILACIÓN INICIAL PARA CALCULAR TAMAÑOS
    # - fabricar artefactos.
    ########################################################################################
    print_debug("====> [PASADA 1] Compilación inicial para calcular tamaños...")
    print_debug("")

    # Compilar stage1
    stage1_result, output = compile_asm(
        filename=STAGE1_ASM,
        artifact=STAGE1_ARTIFACT,
    )

    if stage1_result != 0:
        print_debug(f"[ERROR] Compilando [{STAGE1_ASM}]:")
        print_debug(output)
        sys.exit(1)

    # Siempre empezamos con 512 bytes de tamaño (el MBR).
    total_size = 512
    stage1_sectors = 1
    total_sectors = stage1_sectors
    print_debug(f"\t{STAGE1_ARTIFACT}: 512 bytes/1 sector.")
    print_debug("")

    # Compilar stage2 (temporal, sin structure.asm correcto)
    stage2_result, output2 = compile_asm(
        filename=STAGE2_ASM,
        artifact=STAGE2_ARTIFACT
    )

    if stage2_result != 0:
        print_debug(f"[ERROR] Compilando [{STAGE2_ASM}]:")
        print_debug(output2)
        sys.exit(2)

    stage2_size = file_size(filename=STAGE2_ARTIFACT)
    total_size += stage2_size  # sumamos tamaño de stage2.bin
    stage2_sectors = size_in_sectors(size=stage2_size)
    total_sectors += stage2_sectors
    print_debug(f"\t{STAGE2_ARTIFACT}: {stage2_size} bytes/{stage2_sectors} sectors.")
    print_debug("")

    # Calcular tamaño del kernel
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] [KERNEL] Calcular tamaño:")
    kernel_size = file_size(filename=KERNEL)
    total_size += kernel_size
    # En sectores, naturalmente:
    kernel_sectors = size_in_sectors(size=kernel_size)
    total_sectors += kernel_sectors
    print_debug(f"\t{KERNEL}: {kernel_size} bytes/{kernel_sectors} sectors.")
    print_debug("")

    # Construir initrd
    if SKIP_INITRD_BUILD is False:
        initrd_result, output3 = build_initrd(artifact=INITRD_ARTIFACT)
        if initrd_result != 0:
            print_debug("[ERROR] Creando [initrd.bootloader.gz]:")
            print_debug(output3)
            sys.exit(3)
        print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Invocación de la creación de initrd [{INITRD_ARTIFACT}] terminada.")
    else:
        print_debug("[***] INITRD no recreado (SKIP_INITRD_BUILD=True).")
        print_debug("")

    initrd_size = file_size(filename=INITRD_ARTIFACT)
    total_size += initrd_size

    initrd_sectors = size_in_sectors(size=initrd_size)
    total_sectors += initrd_sectors

    print_debug("")
    print_debug("="*79)
    print_debug(f"\t{INITRD_ARTIFACT}: {initrd_size} bytes/{initrd_sectors} sectors.")
    print_debug("="*79)
    print_debug(f"\t[FULL DISK]: {total_size} bytes/{total_sectors} sectors.")
    print_debug("="*79)
    ########################################################################################
    # CALCULAR TAMAÑOS ESTIMADOS:
    # 1. Calcular posiciones correctas.
    # 2. Generar structure.asm: luego segunda pasada de compilación.
    ########################################################################################
    # 1. Calcular posiciones correctas.
    ########################################################################################
    stage1_sector_begin = 0
    stage1_sector_end = 1
    stage1_byte_begin = 0
    stage1_byte_end = 511

    stage2_sector_begin = 1
    stage2_sector_end = stage2_sector_begin + stage2_sectors
    stage2_byte_begin = 512
    stage2_byte_end = stage2_byte_begin + stage2_size

    # Calcular el siguiente sector natural desde stage1_size + stage2_size
    stages_size = 512 + stage2_size
    kernel_next_natural_sector_position_in_bytes = stages_size % BS
    if kernel_next_natural_sector_position_in_bytes == 0:
        kernel_next_natural_sector_position_in_bytes = stages_size
    else:
        bytes_to_next_sector = BS - kernel_next_natural_sector_position_in_bytes
        kernel_next_natural_sector_position_in_bytes = stages_size + bytes_to_next_sector

    kernel_sector_begin = kernel_next_natural_sector_position_in_bytes // BS  # es entero, alineado.
    kernel_sector_end = kernel_sector_begin + kernel_sectors
    kernel_bytes_begin = kernel_next_natural_sector_position_in_bytes
    kernel_bytes_end = kernel_bytes_begin + kernel_size

    # Calcular el siguiente sector natural desde kernel_bytes_begin + kernel_size (kernel_bytes_end)
    signature_1_next_natural_sector_position_in_bytes = kernel_bytes_end % BS
    if signature_1_next_natural_sector_position_in_bytes == 0:
        signature_1_next_natural_sector_position_in_bytes = kernel_bytes_end
    else:
        bytes_to_next_sector = BS - signature_1_next_natural_sector_position_in_bytes
        signature_1_next_natural_sector_position_in_bytes = kernel_bytes_end + bytes_to_next_sector

    # Firma: 0xdeadbeef
    signature_1_bytes_begin = signature_1_next_natural_sector_position_in_bytes
    signature_1_bytes_end = signature_1_next_natural_sector_position_in_bytes + 4  # 4 bytes
    signature_1_sector_begin = signature_1_next_natural_sector_position_in_bytes // BS
    signature_1_sector_end = signature_1_sector_begin  # +4 bytes, es el mismo sector.

    # INITRD: tras la firma, sector natural.
    # Calcular el siguiente sector natural desde kernel_bytes_begin + kernel_size (kernel_bytes_end)
    initrd_next_natural_sector_position_in_bytes = signature_1_bytes_end % BS
    if initrd_next_natural_sector_position_in_bytes == 0:
        initrd_next_natural_sector_position_in_bytes = signature_1_bytes_end
    else:
        bytes_to_next_sector = BS - initrd_next_natural_sector_position_in_bytes
        initrd_next_natural_sector_position_in_bytes = signature_1_bytes_end + bytes_to_next_sector

    initrd_bytes_begin = initrd_next_natural_sector_position_in_bytes
    initrd_bytes_end = initrd_next_natural_sector_position_in_bytes + initrd_size
    initrd_sector_begin = initrd_next_natural_sector_position_in_bytes // BS
    initrd_sector_end = initrd_bytes_end // BS

    print_debug("")
    print_debug("="*79)
    print_debug(f"[POSICIONES CALCULADAS]:")
    print_debug(f"  kernel_sector_begin: {kernel_sector_begin}")
    print_debug(f"  kernel_bytes_begin: {kernel_bytes_begin}/{hex(kernel_bytes_begin)}")
    print_debug(f"  kernel_sectors: {kernel_sectors}")
    print_debug(f"  kernel_sector_end: {kernel_sector_end}")
    print_debug("")
    print_debug(f"  initrd_sector_begin: {initrd_sector_begin}")
    print_debug(f"  initrd_bytes_begin: {initrd_bytes_begin}/{hex(initrd_bytes_begin)}")
    print_debug(f"  initrd_sectors: {initrd_sectors}")
    print_debug(f"  initrd_sector_end: {initrd_sector_end}")
    print_debug("="*79)
    print_debug("")

    print_debug("[GENERANDO structure.asm con valores calculados...]")
    rebuild_structure_asm(
        stage1_start_sector=0,
        stage1_sectors=1,
        stage2_start_sector=1,
        stage2_size_sectors=stage2_sectors,
        stage2_size_bytes=stage2_size,
        kernel_start_sector=kernel_sector_begin,
        kernel_size_sectors=kernel_sectors,
        kernel_size_bytes=kernel_size,
        initrd_start_sector=initrd_sector_begin,
        initrd_size_sectors=initrd_sectors,
        initrd_size_bytes=initrd_size
    )

    ########################################################################################
    # PASADA 2: RECOMPILAR STAGE2 CON structure.asm CORRECTO
    ########################################################################################
    print("")
    print_debug("====> [PASADA 2] Recompilando stage2 con structure.asm correcto...")

    stage2_result, output2 = compile_asm(
        filename=STAGE2_ASM,
        artifact=STAGE2_ARTIFACT,
    )

    if stage2_result != 0:
        print_debug(f"[ERROR] Recompilando [{STAGE2_ASM}]:")
        print_debug(output2)
        sys.exit(2)

    # Verificar que el tamaño no cambió
    stage2_size_final = file_size(filename=STAGE2_ARTIFACT)
    if stage2_size_final != stage2_size:
        print_debug(f"[ADVERTENCIA] Stage2 cambió de tamaño: {stage2_size} -> {stage2_size_final}")
        print_debug(f"[ADVERTENCIA] Esto puede causar problemas. Considera ajustar STAGE2_SECTORS.")

    print_debug(f"[OK] Stage2 recompilado: {stage2_size_final} bytes")
    print("")

    # Leer binarios finales
    stage1_bin = read_binary(filename=STAGE1_ARTIFACT)
    stage2_bin = read_binary(filename=STAGE2_ARTIFACT)
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
    print_debug(f"[!] Preparado para grabar [{kernel_size}] bytes de KERNEL en: [{DISK_FILENAME}]:")
    kernel_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=kernel_bin,
        bs=BS,
        sector=kernel_sector_begin
    )
    if kernel_write_result == 0:
        print_debug(f"[ERROR] Grabando KERNEL en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{kernel_write_result}] bytes de KERNEL en: [{DISK_FILENAME}]:")

    # Cerrar kernel con firma 0xdeadbeef:
    add_signature(filename=DISK_FILENAME,
                  signature=0xdeadbeef,
                  position_bytes=signature_1_bytes_begin, bs=BS)

    # Escribir initrd
    print("")
    print_debug(f"[OK] Iniciando grabación de INITRD en: [{DISK_FILENAME}]:")
    initrd_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=initrd_bin,
        bs=BS,
        sector=initrd_sector_begin
        #position_bytes=initrd_bytes_begin
    )

    if initrd_write_result == 0:
        print_debug(f"[ERROR] Grabando INITRD en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{initrd_write_result}] bytes de INITRD en: [{DISK_FILENAME}]:")

    close_signature_position = initrd_bytes_end + 8  # 8 bytes offset adicional.

    # Cerrar initrd con firmas:
    add_signature(filename=DISK_FILENAME,
                  signature=0x44444444,
                  position_bytes=close_signature_position, bs=BS)

    add_signature(filename=DISK_FILENAME,
                  signature=0x43434343,
                  position_bytes=close_signature_position + 4, bs=BS)

    add_signature(filename=DISK_FILENAME,
                  signature=0x42424242,
                  position_bytes=close_signature_position + 8, bs=BS)

    add_signature(filename=DISK_FILENAME,
                  signature=0x41414141,
                  position_bytes=close_signature_position + 12, bs=BS)

    print("")
    print_debug(f"[POSICIONES FINALES] (en sectores):")
    print_debug("[stage1] => 0")
    print_debug("[stage2] => 1")
    print_debug(f"[kernel] => {kernel_sector_begin}")
    print_debug(f"[initrd] => {initrd_sector_begin}")
    print_debug("--- END ---")

    print("")
    print_debug(f"[POSICIONES FINALES] (en bytes):")
    print_debug("[stage1] => 0")
    print_debug("[stage2] => 512")
    print_debug(f"[kernel] => {kernel_bytes_begin}/{hex(kernel_bytes_begin)}")
    print_debug(f"[initrd] => {initrd_bytes_begin}/{hex(initrd_bytes_begin)}")
    print_debug("--- END ---")

    print("")
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] [OK] Todo completado.")
    sys.exit(0)
