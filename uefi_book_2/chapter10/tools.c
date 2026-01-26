#include "tools.h"


VOID Hex_Dump (IN VOID *Buffer, IN UINTN Size) {
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


VOID Halt_Execution(VOID) {
    while (TRUE) {
        // En EDK II, es mejor usar una llamada que no consuma CPU
        gBS->Stall (1000000);  // Esperar 1 segundo
        // Igualmente invocamos HALT.
        asm volatile("hlt");
    }
}


EFI_STATUS get_efi_variable(CHAR16    *VariableName,
                            EFI_GUID  *TargetGuid,
                            VOID      **Data,
                            UINTN     *DataSize) {
    EFI_STATUS  Status;
    UINT32      Attributes;
    UINTN       Size = 0;

    // Primera llamada para obtener el tamaño
    Status = uefi_call_wrapper(RT->GetVariable, 5,
                               VariableName,
                               TargetGuid,
                               NULL,           // Attributes (puede ser NULL si no te interesan)
                               &Size,
                               NULL            // Data = NULL para obtener solo el tamaño
    );

    if (Status != EFI_BUFFER_TOO_SMALL) {
        return Status;
    }

    // Asignar memoria para los datos
    *Data = AllocatePool(Size);
    if (*Data == NULL) {
        return EFI_OUT_OF_RESOURCES;
    }

    // Segunda llamada para obtener los datos reales
    Status = uefi_call_wrapper(RT->GetVariable, 5,
                               VariableName,
                               TargetGuid,
                               &Attributes,    // Opcionalmente puedes obtener los atributos
                               &Size,
                               *Data
    );

    if (EFI_ERROR(Status)) {
        FreePool(*Data);
        *Data = NULL;
        return Status;
    }

    *DataSize = Size;
    return EFI_SUCCESS;
}

//VOID *Data = NULL;
//UINTN DataSize = 0;
//EFI_GUID GlobalVariable = EFI_GLOBAL_VARIABLE;
//EFI_STATUS Status = get_efi_variable(
//L"SecureBoot",
//&GlobalVariable,
//&Data,
//&DataSize
//);

EFI_STATUS set_efi_variable(CHAR16 *VariableName,
                            EFI_GUID *TargetGuid,
                            UINT32 Attributes,
                            UINTN DataSize,
                            VOID *Data) {
    EFI_STATUS Status;

    Status = uefi_call_wrapper(
        RT->SetVariable,
        5,
        VariableName,
        TargetGuid,
        Attributes,
        DataSize,
        Data
    );

    return Status;
}


EFI_STATUS delete_efi_variable(CHAR16    *VariableName,
                               EFI_GUID  *TargetGuid) {
    // Establecer DataSize = 0 elimina la variable
    return uefi_call_wrapper(RT->SetVariable, 5,
                             VariableName,
                             TargetGuid,
                             0,              // Attributes = 0
                             0,              // DataSize = 0
                             NULL            // Data = NULL
    );
}

EFI_STATUS Load_File(EFI_FILE_PROTOCOL *Root, CHAR16 *Path, VOID **Buffer, UINTN *Size) {
    EFI_STATUS Status;
    EFI_FILE_PROTOCOL *File;
    EFI_FILE_INFO *FileInfo;
    UINTN FileInfoSize;

    // Abrir el archivo
    Status = uefi_call_wrapper(Root->Open, 5, Root, &File, Path, EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(Status)) {
        Print(L"Error abriendo archivo %s: %r\n", Path, Status);
        return Status;
    }
    Print(L"Archivo abierto %s: %r\n", Path, Status);

    // Obtener información del archivo
    FileInfoSize = SIZE_OF_EFI_FILE_INFO + 256;
    FileInfo = AllocatePool(FileInfoSize);
    if (!FileInfo) {
        uefi_call_wrapper(File->Close, 1, File);
        return EFI_OUT_OF_RESOURCES;
    }
    Print(L"FileInfo ok %s\n", Path);

    Status = uefi_call_wrapper(File->GetInfo, 4, File, &gEfiFileInfoGuid, &FileInfoSize, FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Error obteniendo info de archivo: %r\n", Status);
        FreePool(FileInfo);
        uefi_call_wrapper(File->Close, 1, File);
        return Status;
    }

    *Size = FileInfo->FileSize;
    Print(L"FileSize ok %d\n", FileInfo->FileSize);

    FreePool(FileInfo);

    // Asignar memoria para el archivo
    *Buffer = AllocatePool(*Size);
    if (!*Buffer) {
        uefi_call_wrapper(File->Close, 1, File);
        return EFI_OUT_OF_RESOURCES;
    }

    // Leer el archivo
    Status = uefi_call_wrapper(File->Read, 3, File, Size, *Buffer);
    if (EFI_ERROR(Status)) {
        Print(L"Error leyendo archivo: %r\n", Status);
        FreePool(*Buffer);
        *Buffer = NULL;
    }

    uefi_call_wrapper(File->Close, 1, File);
    return Status;
}


EFI_INPUT_KEY WaitForKey(CONST CHAR16 *Prompt) {
    EFI_INPUT_KEY  Key;
    UINTN          Index;

    uefi_call_wrapper(ST->ConIn->Reset, 2,
                      ST->ConIn,
                      FALSE);

    Print(Prompt);

    uefi_call_wrapper(BS->WaitForEvent, 3,
                      1,  // Número de eventos
                      &ST->ConIn->WaitForKey,
                      &Index);

    uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2,
                      ST->ConIn,
                      &Key);

    return Key;
}

EFI_STATUS SetCursorPosition(UINTN x, UINTN y) {
    return uefi_call_wrapper(ST->ConOut->SetCursorPosition, 3,
                             ST->ConOut, x, y);
}


EFI_STATUS ClearScreen(VOID) {
    return uefi_call_wrapper(ST->ConOut->ClearScreen, 1,
                             ST->ConOut);
}


VOID Sleep(UINTN Microseconds) {
    uefi_call_wrapper(BS->Stall, 1,
                      Microseconds);
}
