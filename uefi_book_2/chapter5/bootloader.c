#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>


// El propio boot:
// - importante L
// - importante el PATH completo.
#define TEST_FILE_NAME L"\\EFI\\BOOT\\BOOTX64.EFI"


VOID Halt_Execution(VOID) {
    while (TRUE) {
      // En EDK II, es mejor usar una llamada que no consuma CPU
      gBS->Stall (1000000);  // Esperar 1 segundo
    }
}


EFI_FILE_HANDLE
GetVolume (IN EFI_HANDLE image) {
    EFI_STATUS                       Status;
    EFI_LOADED_IMAGE_PROTOCOL        *loaded_image;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL  *FileSystem;
    EFI_FILE_PROTOCOL                *Volume;

    // Obtener el protocolo "LoadedImage"
    Status = gBS->HandleProtocol (
                    image,
                    &gEfiLoadedImageProtocolGuid,
                    (VOID **)&loaded_image
                    );

    if (EFI_ERROR (Status)) {
      return NULL;
    }

    // Obtener el protocolo "SimpleFileSystem" del dispositivo
    Status = gBS->HandleProtocol (
                    loaded_image->DeviceHandle,
                    &gEfiSimpleFileSystemProtocolGuid,
                    (VOID **)&FileSystem
                    );

    if (EFI_ERROR (Status)) {
      return NULL;
    }

    // Abrir el volumen raíz
    Status = FileSystem->OpenVolume (FileSystem, &Volume);
    if (EFI_ERROR (Status)) {
      return NULL;
    }

    return Volume;
}


EFI_STATUS
GetFileSize (IN  EFI_FILE_PROTOCOL *File, OUT UINT64 *FileSize) {
    EFI_STATUS     Status;
    EFI_FILE_INFO  *FileInfo = NULL;
    UINTN          BufferSize = SIZE_OF_EFI_FILE_INFO + 200;

    Status = File->GetInfo (File,
                            &gEfiFileInfoGuid,
                            &BufferSize,
                            NULL);

    if (Status == EFI_BUFFER_TOO_SMALL) {
        FileInfo = AllocatePool (BufferSize);
        if (FileInfo == NULL) {
            return EFI_OUT_OF_RESOURCES;
        }

        // Obtener la información del archivo
        Status = File->GetInfo (File,
                                &gEfiFileInfoGuid,
                                &BufferSize,
                                FileInfo);
    }

    if (!EFI_ERROR (Status)) {
        *FileSize = FileInfo->FileSize;
    }

    if (FileInfo != NULL) {
        FreePool (FileInfo);
    }

    return Status;
}


VOID
HexDump (IN VOID *Buffer, IN UINTN Size) {
    UINT8 *Data = (UINT8 *)Buffer;
    UINTN i, j;

    for (i = 0; i < Size; i += 16) {
        // Imprimir offset
        Print (L"%08x  ", i);

        // Imprimir bytes en hexadecimal
        for (j = 0; j < 16; j++) {
            if (i + j < Size) {
                Print (L"%02x ", Data[i + j]);
            } else {
                Print (L"   ");  // Espacios si no hay más datos
            }

            // Separador en medio
            if (j == 7) {
                Print (L" ");
            }
        }

        Print (L" |");

        // Imprimir representación ASCII
        for (j = 0; j < 16 && i + j < Size; j++) {
            UINT8 c = Data[i + j];
            if (c >= 32 && c <= 126) {
                Print (L"%c", c);
            } else {
                Print (L".");
            }
        }

        Print (L"|\n");
    }
}


EFI_STATUS
EFIAPI
UefiMain (IN EFI_HANDLE ImageHandle,IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS       Status;
    EFI_FILE_HANDLE  fileHandle0 = NULL;
    EFI_FILE_HANDLE  volume0;
    // Usaremos dos variables, en vez de una (por el tamaño)
    UINT64           fileSize0;
    UINTN            readSize0;
    UINT8            *buffer0 = NULL;

    Print (L"1) volume = GetVolume(ImageHandle):\n");
    volume0 = GetVolume(ImageHandle);

    if (volume0 == NULL) {
        Print (L"X) ERROR: No se pudo obtener el volumen\n");
        Halt_Execution();
    }

    Print (L"   Volume=0x%p\n", volume0);

    Print (L"2) Open file => FileHandle:\n");
    Status = volume0->Open(
                      volume0,
                      &fileHandle0,
                      TEST_FILE_NAME,
                      EFI_FILE_MODE_READ,
                      0);

    if (EFI_ERROR (Status)) {
        Print (L"X) ERROR: No se pudo abrir el archivo (Status = %r)\n", Status);
        Halt_Execution();
    }

    // Obtener tamaño del archivo
    Status = GetFileSize(fileHandle0, &fileSize0);
    if (EFI_ERROR (Status)) {
        Print (L"X) ERROR: No se pudo obtener el tamaño del archivo\n");
        Halt_Execution();
    }

    Print (L"   fileSize=%lld bytes\n", fileSize0);

    // Reservar memoria para el contenido del archivo
    buffer0 = AllocatePool((UINTN)fileSize0);
    if (buffer0 == NULL) {
        Print (L"X) ERROR: No se pudo asignar memoria\n");
        Status = EFI_OUT_OF_RESOURCES;
        Halt_Execution();
    }

    Print (L"3) Read file => Buffer:\n");

    // Leer el archivo
    readSize0 = (UINTN)fileSize0;
    Status = fileHandle0->Read(fileHandle0, &readSize0, buffer0);
    if (EFI_ERROR (Status)) {
        Print (L"X) ERROR: No se pudo leer el archivo (Status = %r)\n", Status);
        Halt_Execution();
    }

    Print (L"   [%d] bytes read OK.\n\n", readSize0);
    Print (L"4) Hexdump:\n");
    Print (L"==============================================================================\n");

    HexDump (buffer0, readSize0);

    Print (L"==============================================================================\n");
    Print (L"5) COMPLETED!\n");
    Print (L"==============================================================================\n\n");

    if (buffer0 != NULL) {
        FreePool(buffer0);
    }

    if (fileHandle0 != NULL) {
        fileHandle0->Close(fileHandle0);
    }

    if (volume0 != NULL) {
        volume0->Close(volume0);
    }

    Halt_Execution();

    return EFI_SUCCESS;
}
