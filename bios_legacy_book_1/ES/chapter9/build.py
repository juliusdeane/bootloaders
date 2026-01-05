#!/usr/bin/env python3

import os
import sys
import math
import subprocess as sp


DEBUG = os.getenv("DEBUG", True)
if DEBUG is not True:
    DEBUG = False

CHAPTER_NUMBER = 9

SKIP_DISK = os.getenv("SKIP_DISK", False)
if SKIP_DISK is not False:
    SKIP_DISK = True

ASM = os.getenv("ASM", "/usr/bin/nasm")
CC = os.getenv("CC", "/usr/bin/x86_64-linux-gnu-gcc")
OBJCOPY = os.getenv("OBJCOPY", "/usr/bin/x86_64-linux-gnu-objcopy")
DD = os.getenv("DD", "/usr/bin/dd")
EMU = os.getenv("EMU", "/usr/bin/qemu-system-x86_64")
EMU386 = os.getenv("DD", "/usr/bin/qemu-system-i386")
SH = os.getenv("SH", "/bin/sh")
RM = os.getenv("RM", "/bin/rm")
DISK_FILENAME = os.getenv("DISK_FILENAME", "disk.img")
BS = 512

STAGE1_ASM = "stage1.asm"
STAGE2_ASM = "stage2.asm"
STAGE3_ASM = "stage3.asm"
KERNEL_C_SOURCE = "kernel.c"

STAGE1_ARTIFACT = "stage1.bin"
STAGE2_ARTIFACT = "stage2.bin"
STAGE3_ARTIFACT = "stage3.bin"
KERNEL_C_ARTIFACT = "kernel.bin"

EXTRA_SECTORS_AT_END = os.getenv("EXTRA_SECTORS_AT_END", 8192)
if EXTRA_SECTORS_AT_END != 8192:
    try:
        EXTRA_SECTORS_AT_END = int(EXTRA_SECTORS_AT_END)
    except:  # noqa
        EXTRA_SECTORS_AT_END = 8192

KERNEL_ADDRESS = '0x300000'

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

    :return: Una tuple con el código de status de la ejecución con run y el texto de la salida estándar.
    """
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Limpiando entorno:")
    prc = sp.run(
        [
            RM,
            "-rf",
            STAGE1_ARTIFACT, STAGE2_ARTIFACT, STAGE3_ARTIFACT,
            KERNEL_C_ARTIFACT,
            KERNEL_C_ARTIFACT + '.text', KERNEL_C_ARTIFACT + '.rodata', KERNEL_C_ARTIFACT + '.data',
            DISK_FILENAME,
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
    :return: Una tuple con el código de status de la ejecución con run, el texto de la salida estándar y el de stderr.
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

    return prc.returncode, prc.stdout, prc.stderr

def compile_c(filename: str, artifact: str):
    """
    Compila un ".c" (flat binary) con la herramienta determinada en la variable CC (gcc, por ejemplo).

    :param filename: El fichero ".c" de entrada.
    :param artifact: El artefacto (.bin) de salida.
    :return: Una tuple con el código de status de la ejecución con run, el texto de la salida estándar y el de stderr.
    """
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Compilando [{filename}] => [{artifact}]:")

# x86_64-elf-gcc -ffreestanding -nostdlib -nostartfiles \
# -fno-pic -fno-pie \
# -mcmodel=kernel \
# -mno-red-zone -mno-mmx -mno-sse -mno-sse2 \
# -Wl,--oformat=binary \
# -Wl,-Ttext=0x100000 \
# -o kernel.bin kernel.c

    prc = sp.run(
        [
            CC,
            '-ffreestanding', '-nostdlib', '-nostartfiles',
            '-fno-pic', '-fno-pie',
            '-mcmodel=kernel',
            '-mno-red-zone', '-mno-mmx', '-mno-sse', '-mno-sse2',
            '-Wl,--oformat=binary',
            f'-Wl,-Ttext={KERNEL_ADDRESS}',
            filename,
            "-o", artifact
        ],
        capture_output=True,
        text=True
    )

    return prc.returncode, prc.stdout, prc.stderr

def concatenate_pre_artifacts(artifact:str,
                              text_artifact:str,
                              rodata_artifact:str, data_artifact:str):
    try:
        with open(artifact, 'wb') as output_file:  # 'wb' = write binary
            # Concatenar .text
            with open(text_artifact, 'rb') as f:  # 'rb' = read binary
                output_file.write(f.read())

            # Concatenar .rodata
            with open(rodata_artifact, 'rb') as f:
                output_file.write(f.read())

            # Concatenar .data (si existe)
            if os.path.exists(data_artifact):
                with open(data_artifact, 'rb') as f:
                    output_file.write(f.read())

        print_debug(f"Kernel creado: {artifact}")
        return True
    except Exception as e:
        print_debug(f"Kernel NO creado: {artifact}")
        print_debug(f"Excepción: {e}")
    return False


def compile_c2(filename: str, artifact: str):
    """
    Compila un ".c" (flat binary) con la herramienta determinada en la variable CC (gcc, por ejemplo).

    :param filename: El fichero ".c" de entrada.
    :param artifact: El artefacto (.bin) de salida.
    :return: Una tuple con el código de status de la ejecución con run, el texto de la salida estándar y el de stderr.
    """
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] Compilando [{filename}] => [{artifact}]:")

# Pre-artifact
# x86_64-elf-gcc -ffreestanding -fno-pic -fno-pie \
#                -mcmodel=kernel -mno-red-zone \
#                -fno-asynchronous-unwind-tables \
#                -fno-unwind-tables \
#                -fno-exceptions \
#                -O0 \
#                -fno-stack-protector \
# -c kernel.c -o kernel.o
    preartifact = artifact + ".o"
    prc = sp.run(
        [
            CC,
            '-ffreestanding', '-fno-pic', '-fno-pie',
            '-fno-asynchronous-unwind-tables', '-fno-unwind-tables',
            '-fno-exceptions',
            '-mcmodel=kernel', '-mno-red-zone',
            '-O0', '-fno-stack-protector',
            '-c', filename,
            "-o", preartifact
        ],
        capture_output=True,
        text=True
    )
    # Verificar si hemos tenido error en compilación.
    if prc.returncode != 0:
        return prc.returncode, prc.stdout, prc.stderr

# x86_64-elf-objcopy -O binary kernel.o kernel.bin
#                    -j .text -j .rodata -j .data \
    text_artifact = artifact + '.text'
    prc2 = sp.run(
        [
            OBJCOPY,
            '-O', 'binary',
            '-j', '.text',
            preartifact, text_artifact
        ],
        capture_output=True,
        text=True
    )
    # Verificar si hemos tenido error extrayendo .text:
    if prc2.returncode != 0:
        return prc2.returncode, prc2.stdout, prc2.stderr

    rodata_artifact = artifact + '.rodata'
    prc3 = sp.run(
        [
            OBJCOPY,
            '-O', 'binary',
            '-j', '.rodata',
            preartifact, rodata_artifact
        ],
        capture_output=True,
        text=True
    )
    # Verificar si hemos tenido error extrayendo .rodata:
    if prc3.returncode != 0:
        return prc3.returncode, prc3.stdout, prc3.stderr

    data_artifact = artifact + '.data'
    prc4 = sp.run(
        [
            OBJCOPY,
            '-O', 'binary',
            '-j', '.data',
            preartifact, data_artifact
        ],
        capture_output=True,
        text=True
    )
    # Verificar si hemos tenido error extrayendo .rodata:
    if prc4.returncode != 0:
        return prc4.returncode, prc4.stdout, prc4.stderr

    concat_res = concatenate_pre_artifacts(artifact=artifact,
                                           text_artifact=text_artifact,
                                           rodata_artifact=rodata_artifact,
                                           data_artifact=data_artifact)
    if concat_res:
        return 0, "", ""
    return 1, "ERROR concatenando binarios", "ERROR concatenando binarios"


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
        position = sector * bs  # noqa
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
    stage1_size_bytes = kwargs.get("stage1_size_bytes", 512)

    stage2_start_sector = kwargs.get("stage2_start_sector", 1)
    stage2_size_sectors = kwargs.get("stage2_size_sectors", 16)
    stage2_size_bytes = kwargs.get("stage2_size_bytes", 8192)

    stage3_start_sector = kwargs.get("stage3_start_sector", 17)
    stage3_size_sectors = kwargs.get("stage3_size_sectors", 16)
    stage3_size_bytes = kwargs.get("stage3_size_bytes", 8192)

    kernel_c_start_sector = kwargs.get("kernel_c_start_sector", 33)
    kernel_c_size_sectors = kwargs.get("kernel_c_size_sectors", 32)
    kernel_c_size_bytes = kwargs.get("kernel_c_size_bytes", 16384)

    structure_asm = f'''; THIS FILE MUST BE AUTOGENERATED BY boot.py: do not modify.
STAGE1_START_SECTOR     equ {stage1_start_sector}
STAGE1_SIZE_SECTORS     equ {stage1_size_sectors}
STAGE1_SIZE_BYTES       equ {stage1_size_bytes}

STAGE2_START_SECTOR     equ {stage2_start_sector}
STAGE2_SIZE_SECTORS     equ {stage2_size_sectors}
STAGE2_SIZE_BYTES       equ {stage2_size_bytes}

STAGE3_START_SECTOR     equ {stage3_start_sector}
STAGE3_SIZE_SECTORS     equ {stage3_size_sectors}
STAGE3_SIZE_BYTES       equ {stage3_size_bytes}

KERNEL_C_START_SECTOR   equ {kernel_c_start_sector}
KERNEL_C_SIZE_SECTORS   equ {kernel_c_size_sectors}
KERNEL_C_SIZE_BYTES     equ {kernel_c_size_bytes}

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
    # Fabricar artefactos.
    ########################################################################################
    # Compilar stage1
    stage1_result, output, err = compile_asm(
        filename=STAGE1_ASM,
        artifact=STAGE1_ARTIFACT,
    )

    if stage1_result != 0:
        print_debug(f"[ERROR] Compilando [{STAGE1_ASM}]:")
        print_debug(output)
        print_debug(err)
        sys.exit(1)

    # Siempre empezamos con 512 bytes de tamaño (el MBR).
    total_size = 512
    stage1_sectors = 1
    total_sectors = stage1_sectors
    print_debug(f"\t{STAGE1_ARTIFACT}: 512 bytes/1 sector.")
    print_debug("")

    # Compilar stage2
    stage2_result, output2, err2 = compile_asm(
        filename=STAGE2_ASM,
        artifact=STAGE2_ARTIFACT
    )

    if stage2_result != 0:
        print_debug(f"[ERROR] Compilando [{STAGE2_ASM}]:")
        print_debug(output2)
        print_debug(err2)
        sys.exit(2)

    stage2_size = file_size(filename=STAGE2_ARTIFACT)
    total_size += stage2_size  # sumamos tamaño de stage2.bin
    stage2_sectors = size_in_sectors(size=stage2_size)
    total_sectors += stage2_sectors
    print_debug(f"\t{STAGE2_ARTIFACT}: {stage2_size} bytes/{stage2_sectors} sectors.")
    print_debug("")

    # Compilar stage3
    stage3_result, output3, err3 = compile_asm(
        filename=STAGE3_ASM,
        artifact=STAGE3_ARTIFACT
    )

    if stage3_result != 0:
        print_debug(f"[ERROR] Compilando [{STAGE3_ASM}]:")
        print_debug(output3)
        print_debug(err3)
        sys.exit(2)

    stage3_size = file_size(filename=STAGE3_ARTIFACT)
    total_size += stage3_size  # sumamos tamaño de stage3.bin
    stage3_sectors = size_in_sectors(size=stage3_size)
    total_sectors += stage3_sectors
    print_debug(f"\t{STAGE3_ARTIFACT}: {stage3_size} bytes/{stage3_sectors} sectors.")
    print_debug("")

    # Compilar kernel.c
    kernel_c_result, output_kern, err4 = compile_c2(
        filename=KERNEL_C_SOURCE,
        artifact=KERNEL_C_ARTIFACT
    )

    if kernel_c_result != 0:
        print_debug(f"[ERROR] Compilando [{KERNEL_C_SOURCE}]:")
        print_debug(output_kern)
        print_debug(err4)
        sys.exit(2)

    kernel_c_size = file_size(filename=KERNEL_C_ARTIFACT)
    total_size += kernel_c_size  # sumamos tamaño de kernel.bin
    kernel_c_sectors = size_in_sectors(size=kernel_c_size)
    total_sectors += kernel_c_sectors
    print_debug(f"\t{KERNEL_C_ARTIFACT}: {kernel_c_size} bytes/{kernel_c_sectors} sectors.")
    print_debug("")

    stage1_sector_begin = 0
    stage1_sector_end = 1
    stage1_byte_begin = 0
    stage1_byte_end = 511

    stage2_sector_begin = 1
    stage2_sector_end = 17
    stage2_byte_begin = 512
    stage2_byte_end = stage2_byte_begin + stage2_size

    stage3_sector_begin = 17
    stage3_sector_end = stage3_sector_begin + stage3_sectors
    stage3_byte_begin = 8704
    stage3_byte_end = stage3_byte_begin + stage3_size

    kernel_c_sector_begin = 33
    kernel_c_sector_end = kernel_c_sector_begin + kernel_c_sectors
    kernel_c_byte_begin = 16896
    kernel_c_byte_end = kernel_c_byte_begin + kernel_c_size

    # Leer binarios finales
    stage1_bin = read_binary(filename=STAGE1_ARTIFACT)
    stage2_bin = read_binary(filename=STAGE2_ARTIFACT)
    stage3_bin = read_binary(filename=STAGE3_ARTIFACT)
    kernel_c_bin = read_binary(filename=KERNEL_C_ARTIFACT)

    ########################################################################################
    # CONSTRUIR DISCO CON LOS BINARIOS FINALES
    # +tamaño extra al final.
    ########################################################################################
    total_sectors += EXTRA_SECTORS_AT_END

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

    # Escribir stage3
    stage3_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=stage3_bin,
        bs=BS,
        sector=stage3_sector_begin
    )
    if stage3_write_result == 0:
        print_debug(f"[ERROR] Grabando stage3 en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{stage3_write_result}] bytes de stage3 en: [{DISK_FILENAME}]:")

    # Escribir kernel_c
    kernel_c_write_result = write_at(
        filename=DISK_FILENAME,
        binary_data=kernel_c_bin,
        bs=BS,
        sector=kernel_c_sector_begin
    )
    if kernel_c_write_result == 0:
        print_debug(f"[ERROR] Grabando kernel_c en: [{DISK_FILENAME}]:")
        sys.exit(6)
    print_debug(f"[OK] Grabados [{kernel_c_write_result}] bytes de kernel_c en: [{DISK_FILENAME}]:")

    print("")
    print_debug(f"[POSICIONES FINALES] (en sectores):")
    print_debug("[stage1]   => 0")
    print_debug("[stage2]   => 1")
    print_debug("[stage3]   => 17")
    print_debug(f"[kernel.c] => {kernel_c_sector_begin}")
    print_debug("--- END ---")

    print("")
    print_debug(f"[POSICIONES FINALES] (en bytes):")
    print_debug("[stage1]   => 0")
    print_debug("[stage2]   => 512")
    print_debug("[stage3]   => 8704")
    print_debug(f"[kernel.c] => {kernel_c_byte_begin}")
    print_debug("--- END ---")

    print("")
    print_debug(f"[CAPÍTULO {CHAPTER_NUMBER}] [OK] Todo completado.")
    sys.exit(0)
