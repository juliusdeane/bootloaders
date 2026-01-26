#include <efi.h>
#include <efilib.h>


// El propio boot:
// - importante L
// - importante el PATH completo.
#define TEST_FILE_NAME L"\\EFI\\BOOT\\BOOTX64.EFI"


EFI_FILE_HANDLE GetVolume(EFI_HANDLE image) {
    EFI_LOADED_IMAGE       *loaded_image = NULL;
    /* El protocolo de interfaz para IMAGE */
    EFI_GUID               lipGuid = EFI_LOADED_IMAGE_PROTOCOL_GUID;
    /* El GUID del interfaz de I/O */
    EFI_FILE_IO_INTERFACE  *IOVolume;
    /* El GUID del interfaz del sistema de ficheros */
    EFI_GUID               fsGuid =  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    /* El interfaz para el volumen particular */
    EFI_FILE_HANDLE        Volume;

    /* Obtenemos el interfaz del protocolo de IMAGE para
       la nuestra (image) */
    uefi_call_wrapper(BS->HandleProtocol,
                      3,
                      image,
                      &lipGuid,
                      (void **) &loaded_image);

    /* Obtenemos el handle al volumen */
    uefi_call_wrapper(BS->HandleProtocol,
                      3,
                      loaded_image->DeviceHandle,
                      &fsGuid, (VOID*)&IOVolume);

    uefi_call_wrapper(IOVolume->OpenVolume, 2, IOVolume, &Volume);

    return Volume;
}


EFI_STATUS GetFileSize(EFI_FILE_PROTOCOL *File, UINT64 *FileSize) {
    EFI_STATUS        Status;
    EFI_FILE_INFO     *FileInfo;
    UINTN             BufferSize = SIZE_OF_EFI_FILE_INFO + 200;  // Tamaño suficiente para el nombre

    // Asignar memoria para la información del fichero
    Status = uefi_call_wrapper(BS->AllocatePool, 3,
                               EfiLoaderData,
                               BufferSize,
                               (VOID**)&FileInfo);
    if (EFI_ERROR(Status)) {
        return Status;
    }

    // Obtener la información del fichero
    Status = uefi_call_wrapper(File->GetInfo, 4,
                               File,
                               &gEfiFileInfoGuid,
                               &BufferSize,
                               FileInfo);

    if (!EFI_ERROR(Status)) {
        *FileSize = FileInfo->FileSize;
    }

    // Liberar memoria
    uefi_call_wrapper(BS->FreePool, 1, FileInfo);

    return Status;
}

void HexDump(VOID *Buffer, UINTN Size) {
    UINT8 *data = (UINT8 *)Buffer;
    UINTN i, j;

    for (i = 0; i < Size; i += 16) {
        // Imprimir offset
        Print(L"%08x  ", i);

        // Imprimir bytes en hexadecimal
        for (j = 0; j < 16; j++) {
            if (i + j < Size) {
                Print(L"%02x ", data[i + j]);
            } else {
                Print(L"   ");  // Espacios si no hay más datos
            }

            // Separador en medio
            if (j == 7) {
                Print(L" ");
            }
        }

        Print(L" |");

        // Imprimir representación ASCII
        for (j = 0; j < 16 && i + j < Size; j++) {
            UINT8 c = data[i + j];
            if (c >= 32 && c <= 126) {
                Print(L"%c", c);
            } else {
                Print(L".");
            }
        }

        Print(L"|\n");
    }
}


void
EFIAPI
efi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    InitializeLib(ImageHandle, SystemTable);

    EFI_FILE_HANDLE     fileHandle0;
    EFI_FILE_HANDLE     volume0 = GetVolume(ImageHandle);
    UINT64              readSize0 = 0;
    UINT8               *buffer0 = NULL;

    Print(L"1) volume0 = GetVolume(image):\n");
    Print(L"   Volume=0x%x\n", volume0);

    Print(L"2) Open file => fileHandle0:\n");
    uefi_call_wrapper(volume0->Open,
                      5,
                      volume0, &fileHandle0, TEST_FILE_NAME,
                      EFI_FILE_MODE_READ,
                      // Realmente en esta llamada podemos poner 0.
                      EFI_FILE_READ_ONLY | EFI_FILE_HIDDEN | EFI_FILE_SYSTEM);

    // Obtener tamaño:
    // - si hay un error imprimos ERROR.
    if ( EFI_ERROR(GetFileSize(fileHandle0, &readSize0)) ) {
        Print(L"X) ERROR opening file :-?\n");
    }
    else {
        EFI_STATUS readStatus0;
        Print(L"   fileSize=%d\n", readSize0);

        // Reservamos memoria "readSize0" bytes.
        buffer0 = AllocatePool(readSize0);

        Print(L"3) Read file => buffer0:\n");

        // Lo leemos en buffer0.
        readStatus0 = uefi_call_wrapper(fileHandle0->Read, 3, fileHandle0, &readSize0, buffer0);

        if (EFI_ERROR(readStatus0)) {
            Print(L"X) ERROR reading file :-?\n");
        }
        else {
            Print(L"   [%d] bytes read OK.\n\n", readSize0);

            Print(L"4) Hexdump:\n");
            Print(L"==============================================================================\n");

            HexDump(buffer0, readSize0);
        }
    }

    Print(L"==============================================================================\n");
    Print(L"5) COMPLETED!\n");
    Print(L"==============================================================================\n\n");

    while (TRUE) {}
}
