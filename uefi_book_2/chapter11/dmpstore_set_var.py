#!/usr/bin/env python3
"""
UEFI Shell dmpstore file generator: allows to prepare a file that can be loaded into a UEFI variable using dmpstore.
Author: Julius Deane <cloud-svc@juliusdeane.com>
Version: 1.0
"""
import sys
import uuid
import zlib
import struct
import argparse

from pathlib import Path


def generate_dmpstore_file(variable, guid, input_file, attributes, output_file):
    data = None

    # Validar que el archivo de entrada existe
    data_path = Path(input_file)
    if not data_path.exists():
        print(f"[ERROR]: El archivo '{input_file}' no existe", file=sys.stderr)
        sys.exit(1)

    # Leer los datos binarios
    try:
        with open(input_file, 'rb') as f:
            data = f.read()
    except Exception as e:
        print(f"[ERROR]: problemas al leer '{input_file}': {e}", file=sys.stderr)
        sys.exit(1)

    # Parsear el GUID
    try:
        var_guid = uuid.UUID(guid)
    except ValueError as e:
        print(f"[ERROR]: GUID incorrecto '{guid}': {e}", file=sys.stderr)
        sys.exit(1)

    # El nombre de la variable es UTF16, recuerda.
    variable_name_unicode = (variable + '\x00').encode('utf-16le')

    # Construir el contenido principal (sin CRC32 aún)
    content = b''
    content += struct.pack('<I', len(variable_name_unicode))  # NameSize
    content += struct.pack('<I', len(data))                   # DataSize
    content += variable_name_unicode                                 # Name
    content += var_guid.bytes_le                                     # GUID (little-endian)
    content += struct.pack('<I', attributes)                  # Attributes
    content += data                                                  # Data

    crc32_value = zlib.crc32(content) & 0xFFFFFFFF
    output = content + struct.pack('<I', crc32_value)

    # Guardar el archivo
    try:
        with open(output_file, 'wb') as f:
            f.write(output)
    except Exception as e:
        print(f"[ERROR]: al escribir '{output_file}': {e}", file=sys.stderr)
        sys.exit(1)

    # Mostrar resumen
    print(f"[OK]: archivo 'dmpstore' generado correctamente:")
    print(f"    - Variable: {variable}")
    print(f"    - GUID: {guid}")
    print(f"    - Attributes: 0x{attributes:08X}", end="")

    attr_names = []
    if attributes & 0x01:
        attr_names.append("NV")
    if attributes & 0x02:
        attr_names.append("BS")
    if attributes & 0x04:
        attr_names.append("RT")
    if attr_names:
        print(f" ({'+'.join(attr_names)})")
    else:
        print()

    print(f"    - Data size: {len(data)} bytes")
    print(f"    - CRC32: 0x{crc32_value:08X}")
    print(f"    - Output: {output_file} ({len(output)} bytes total)")
    print(f"\nPara cargar en UEFI Shell:")
    print(f"    $ dmpstore -l {Path(output_file).name}")

    # OK!
    sys.exit(0)


def verify_dmpstore_file(input_file):
    """
    Verifica la integridad de un archivo dmpstore existente
    """
    try:
        with open(input_file, 'rb') as f:
            data = f.read()
    except Exception as e:
        print(f"[ERROR]: al intentar leer '{input_file}': {e}", file=sys.stderr)
        sys.exit(1)

    if len(data) < 4:
        print("[ERROR]: archivo demasiado pequeño.", file=sys.stderr)
        sys.exit(1)

    # Separar contenido y CRC32
    content = data[:-4]
    stored_crc32 = struct.unpack('<I', data[-4:])[0]

    # Calcular CRC32
    calculated_crc32 = zlib.crc32(content) & 0xFFFFFFFF

    # Verificar
    if stored_crc32 == calculated_crc32:
        print(f"[OK]: CRC32 válido => 0x{stored_crc32:08X}")
        return True

    print(f"[ERROR]: CRC32 inválido!")
    print(f"    - Almacenado:  0x{stored_crc32:08X}")
    print(f"    - Calculado:   0x{calculated_crc32:08X}")
    return False



def main():
    parser = argparse.ArgumentParser(
        description='Genera y verifica archivos en formato dmpstore para UEFI Shell',
        epilog='''
Ejemplos:
  # Generar archivo dmpstore
  %(prog)s -v MokList -g 605dab50-e046-4300-abb6-3dd810dd8b23 -i cert.der -o mok.bin
  
  # Verificar CRC32 de un archivo existente
  %(prog)s --verify mok.bin
  
Atributos comunes:
  0x01 = NV  (Non-Volatile)
  0x02 = BS  (Boot Service)
  0x04 = RT  (Runtime)
  0x07 = NV+BS+RT (típico para MOK)
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('-v', '--variable',
                        help='Nombre de la variable UEFI (ej: MokList)')

    parser.add_argument('-g', '--guid',
                        help='GUID de la variable (ej: 605dab50-e046-4300-abb6-3dd810dd8b23)')

    parser.add_argument('-i', '--input',
                        metavar='FILE (valor)',
                        help='Archivo binario de entrada con los datos (el valor de la variable)')

    parser.add_argument('-o', '--output',
                        metavar='FILE (para dmpstore)',
                        help='Archivo de salida en formato dmpstore')

    parser.add_argument('-a', '--attributes',
                        type=lambda x: int(x, 0),
                        default=0x07,
                        help='Atributos de la variable (default: 0x07 = NV+BS+RT)')

    parser.add_argument('--verify',
                        metavar='FILE',
                        help='Verificar CRC32 de un archivo dmpstore existente')

    args = parser.parse_args()

    variable = getattr(args, 'variable', None)
    guid = getattr(args, 'guid', None)
    input = getattr(args, 'input', None)
    output = getattr(args, 'output', None)
    attributes = getattr(args, 'attributes', 7)

    # Modo verificación del CRC32 de un fichero existente:
    if args.verify:
        result = verify_dmpstore_file(input_file=args.verify)
        if result:
            print(f"Input file [{args.verify}] verified [OK].")
            sys.exit(0)
        else:
            print(f"Input file [{args.verify}] invalid or not from 'dmpstore' [ERROR].")
            sys.exit(2)

    # Modo generación - validar argumentos requeridos
    if not all([
        variable, guid, input, output
    ]):
        parser.error("Se requieren -v, -g, -i y -o para generar un archivo 'dmpstore'")

    # OK: GENERATE FILE.
    generate_dmpstore_file(variable=variable,
                           guid=guid,
                           input_file=input,
                           attributes=attributes,
                           output_file=output)


if __name__ == "__main__":
    main()

    sys.exit(0)
