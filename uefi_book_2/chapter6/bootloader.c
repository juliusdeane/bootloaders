#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>
#include <Library/DevicePathLib.h>
#include <Protocol/SimpleFileSystem.h>
// IMPORTANTE: muy interesante, esta librería nos ayuda con initrd.
#include <Guid/LinuxEfiInitrdMedia.h>


// ***************************************************************************
// DEFINICIONES DE NOMBRES DE RECURSOS:
// ***************************************************************************
#define KERNEL_FILE_NAME L"\\boot\\vmlinuz"
#define INITRD_FILE_NAME L"\\boot\\initrd.cmp"
// ***************************************************************************
// END: DEFINICIONES DE NOMBRES DE RECURSOS.
// ***************************************************************************


// ***************************************************************************
// DEFINICIONES DE FUNCIONES:
// ***************************************************************************
VOID             Halt_Execution(VOID);
EFI_FILE_HANDLE  GetVolume(IN EFI_HANDLE image);
EFI_STATUS       GetFileSize(IN  EFI_FILE_PROTOCOL *File, OUT UINT64 *FileSize);
VOID             HexDump(IN VOID *Buffer, IN UINTN Size);

EFI_STATUS EFIAPI BootLinuxEfiStub(IN EFI_HANDLE ImageHandle, IN CHAR16 *KernelPath,
                                   IN CHAR16 *InitrdPath, IN CHAR16 *CmdLine);
EFI_STATUS LoadInitrdFile(IN EFI_HANDLE DeviceHandle, IN CHAR16 *Path,
                          OUT VOID **Buffer, OUT UINTN *Size);
EFI_STATUS InstallInitrdProtocol(IN VOID  *InitrdBuffer, IN UINTN InitrdSize);
// ***************************************************************************
// END: DEFINICIONES DE FUNCIONES.
// ***************************************************************************


// ***************************************************************************
// UEFIMAIN:
// - edk2.
// ***************************************************************************
EFI_STATUS
EFIAPI
UefiMain(IN EFI_HANDLE ImageHandle,IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS       kernelStatus;
    EFI_STATUS       initrdStatus;

    EFI_FILE_HANDLE  volume0;

    EFI_FILE_HANDLE  kernelFileHandle = NULL;
    EFI_FILE_HANDLE  initrdFileHandle = NULL;

    // Usaremos dos variables, en vez de una (por el tamaño)
    UINT64           kernelFileSize;
    UINTN            kernelReadSize;

    UINT64           initrdFileSize;
    UINTN            initrdReadSize;

    UINT8            *kernelBuffer = NULL;
    UINT8            *initrdBuffer = NULL;

    Print (L"1) volume0 = GetVolume(ImageHandle):\n");
    volume0 = GetVolume(ImageHandle);

    if (volume0 == NULL) {
        Print (L"X) ERROR: No se pudo obtener el volumen\n");
        Halt_Execution();
    }

    Print (L"   volume0 = 0x%p\n", volume0);

    Print (L"\n2) Open file => kernelFfileHandle:\n");
    kernelStatus = volume0->Open(volume0,
                                 &kernelFileHandle,
                                 KERNEL_FILE_NAME,
                                 EFI_FILE_MODE_READ,
                                 0);

    if (EFI_ERROR (kernelStatus)) {
        Print (L"X) ERROR: No se pudo abrir el archivo del Kernel (kernelStatus = %r)\n", kernelStatus);
        Halt_Execution();
    }

    Print (L"\n2) Open file => initrdFfileHandle:\n");
    // #define INITRD_FILE_NAME L"\\EFI\\BOOT\\initrd.cmp"
    initrdStatus = volume0->Open(volume0,
                                 &initrdFileHandle,
                                 INITRD_FILE_NAME,
                                 EFI_FILE_MODE_READ,
                                 0);

    if (EFI_ERROR (initrdStatus)) {
        Print (L"X) ERROR: No se pudo abrir el archivo del Initrd (initrdStatus = %r)\n", initrdStatus);
        Halt_Execution();
    }

    Print (L"\n3) GetFileSize => kernel:\n");
    // Obtener tamaño del archivo: kernel
    kernelStatus = GetFileSize(kernelFileHandle, &kernelFileSize);
    if (EFI_ERROR (kernelStatus)) {
        Print (L"X) ERROR: No se pudo obtener el tamaño del archivo del kernel.\n");
        Halt_Execution();
    }
    Print (L"   kernelFileSize=%lld bytes\n", kernelFileSize);

    Print (L"\n3) GetFileSize => initrd:\n");
    // Obtener tamaño del archivo: initrd
    initrdStatus = GetFileSize(initrdFileHandle, &initrdFileSize);
    if (EFI_ERROR (initrdStatus)) {
        Print (L"X) ERROR: No se pudo obtener el tamaño del archivo del initrd.\n");
        Halt_Execution();
    }
    Print (L"   initrdFileSize=%lld bytes\n", initrdFileSize);

    // Reservar memoria para el contenido del kernel
    kernelBuffer = AllocatePool((UINTN)kernelFileSize);
    if (kernelBuffer == NULL) {
        Print (L"X) ERROR: No se pudo asignar memoria para el kernel.\n");
        // Status = EFI_OUT_OF_RESOURCES;
        Halt_Execution();
    }

    // Reservar memoria para el contenido del initrd
    initrdBuffer = AllocatePool((UINTN)initrdFileSize);
    if (initrdBuffer == NULL) {
        Print (L"X) ERROR: No se pudo asignar memoria para el initrd.\n");
        // Status = EFI_OUT_OF_RESOURCES;
        Halt_Execution();
    }

    Print (L"\n4) Read KERNEL file => kernelBuffer:\n");
    // Leer el archivo: kernel
    kernelReadSize = (UINTN)kernelFileSize;
    kernelStatus = kernelFileHandle->Read(kernelFileHandle, &kernelReadSize, kernelBuffer);
    if (EFI_ERROR (kernelStatus)) {
        Print (L"X) ERROR: No se pudo leer el archivo de kernel (kernelStatus = %r)\n", kernelStatus);
        Halt_Execution();
    }
    Print (L"   [%d] kernel bytes read OK.\n", kernelReadSize);

    Print (L"\n4) Read INITRD file => initrdBuffer:\n");
    // Leer el archivo: initrd
    initrdReadSize = (UINTN)initrdFileSize;
    initrdStatus = initrdFileHandle->Read(initrdFileHandle, &initrdReadSize, initrdBuffer);
    if (EFI_ERROR (initrdStatus)) {
        Print (L"X) ERROR: No se pudo leer el archivo de initrd (initrdStatus = %r)\n", initrdStatus);
        Halt_Execution();
    }
    Print (L"   [%d] initrd bytes read OK.\n", initrdReadSize);

    // Liberamos porque todavía no lo vamos a usar.
    if (kernelBuffer != NULL) {
        FreePool(kernelBuffer);
    }

    if (initrdBuffer != NULL) {
        FreePool(initrdBuffer);
    }

    if (kernelFileHandle != NULL) {
        kernelFileHandle->Close(kernelFileHandle);
    }

    if (initrdFileHandle != NULL) {
        initrdFileHandle->Close(initrdFileHandle);
    }

    if (volume0 != NULL) {
        volume0->Close(volume0);
    }

    Print (L"\n=== TODO OK ===\n");

    Halt_Execution();

    return EFI_SUCCESS;
}

//EFI_STATUS
//EFIAPI
//UefiMain(
//    IN EFI_HANDLE        ImageHandle,
//    IN EFI_SYSTEM_TABLE  *SystemTable
//){
//    EFI_STATUS Status;

//    Print(L"\n");
//    Print(L"========================================\n");
//    Print(L"   Mi Bootloader - EFI Stub Edition\n");
//    Print(L"========================================\n\n");

    // Arrancar Linux directamente
//    Status = BootLinuxEfiStub(
//        ImageHandle,
//        L"\\boot\\vmlinuz",              // Kernel path
//        L"\\boot\\initrd.img",           // Initrd path (o NULL)
//        L"rdinit=/init.sh rw"            // Command line
//    );

    // Si llegamos aquí, falló
//    Print(L"\nPresiona cualquier tecla para salir...\n");

//    EFI_INPUT_KEY Key;
//    SystemTable->ConIn->Reset(SystemTable->ConIn, FALSE);
//    while (SystemTable->ConIn->ReadKeyStroke(SystemTable->ConIn, &Key) != EFI_SUCCESS);

//    return Status;
//}
// ***************************************************************************
// END: UefiMain.
// ***************************************************************************
// ***************************************************************************
// IMPLEMENTACIONES DE FUNCIONES:
// ***************************************************************************
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
BootLinuxEfiStub(
    IN EFI_HANDLE ImageHandle,
    IN CHAR16     *KernelPath,
    IN CHAR16     *InitrdPath,
    IN CHAR16     *CmdLine
)
{
    EFI_STATUS Status;
    EFI_HANDLE KernelHandle;
    EFI_LOADED_IMAGE_PROTOCOL *LoadedImage;
    EFI_LOADED_IMAGE_PROTOCOL *KernelLoadedImage;
    // EFI_DEVICE_PATH_PROTOCOL *KernelDevicePath;
    VOID *InitrdBuffer = NULL;
    UINTN InitrdSize = 0;

    Print(L"Arrancando Linux con EFI Stub...\n");

    // 1. Obtener información del bootloader actual
    Status = gBS->HandleProtocol(
        ImageHandle,
        &gEfiLoadedImageProtocolGuid,
        (VOID **)&LoadedImage
    );
    if (EFI_ERROR(Status)) {
        Print(L"Error obteniendo LoadedImage: %r\n", Status);
        return Status;
    }

    // 2. Construir device path del kernel
    EFI_DEVICE_PATH_PROTOCOL *BootDevicePath;
    BootDevicePath = DevicePathFromHandle(LoadedImage->DeviceHandle);
    if (BootDevicePath == NULL) {
        Print(L"Error obteniendo device path\n");
        return EFI_NOT_FOUND;
    }

    // Crear file path para el kernel
    EFI_DEVICE_PATH_PROTOCOL *FilePath;
    FilePath = FileDevicePath(LoadedImage->DeviceHandle, KernelPath);
    if (FilePath == NULL) {
        Print(L"Error creando file path para kernel\n");
        return EFI_OUT_OF_RESOURCES;
    }

    Print(L"Cargando kernel: %s\n", KernelPath);

    // 3. Cargar el kernel como imagen UEFI (¡esto es lo mágico!)
    Status = gBS->LoadImage(
        FALSE,                    // BootPolicy
        ImageHandle,              // ParentImageHandle
        FilePath,                 // DevicePath
        NULL,                     // SourceBuffer (NULL = cargar desde path)
        0,                        // SourceSize
        &KernelHandle             // ImageHandle del kernel
    );

    FreePool(FilePath);

    if (EFI_ERROR(Status)) {
        Print(L"Error cargando kernel: %r\n", Status);
        Print(L"¿El kernel tiene EFI stub habilitado?\n");
        return Status;
    }

    Print(L"Kernel cargado exitosamente\n");

    // 4. Configurar el LoadedImage del kernel
    Status = gBS->HandleProtocol(
        KernelHandle,
        &gEfiLoadedImageProtocolGuid,
        (VOID **)&KernelLoadedImage
    );
    if (EFI_ERROR(Status)) {
        Print(L"Error obteniendo LoadedImage del kernel: %r\n", Status);
        gBS->UnloadImage(KernelHandle);
        return Status;
    }

    // 5. Configurar command line
    if (CmdLine != NULL) {
        UINTN CmdLineLen = StrLen(CmdLine);

        // El kernel espera la command line en LoadOptions
        KernelLoadedImage->LoadOptions = AllocateCopyPool(
            (CmdLineLen + 1) * sizeof(CHAR16),
            CmdLine
        );
        KernelLoadedImage->LoadOptionsSize = (UINT32)((CmdLineLen + 1) * sizeof(CHAR16));

        Print(L"Command line: %s\n", CmdLine);
    }

    // 6. Cargar initrd si existe
    if (InitrdPath != NULL) {
        Status = LoadInitrdFile(
            LoadedImage->DeviceHandle,
            InitrdPath,
            &InitrdBuffer,
            &InitrdSize
        );

        if (!EFI_ERROR(Status)) {
            Print(L"Initrd cargado: %s (%d bytes)\n", InitrdPath, InitrdSize);

            // Instalar el protocolo INITRD para que el kernel lo encuentre
            Status = InstallInitrdProtocol(InitrdBuffer, InitrdSize);
            if (EFI_ERROR(Status)) {
                Print(L"Advertencia: No se pudo instalar initrd protocol: %r\n", Status);
            }
        } else {
            Print(L"Advertencia: No se pudo cargar initrd: %r\n", Status);
        }
    }

    Print(L"\n");
    Print(L"=================================\n");
    Print(L"Iniciando kernel...\n");
    Print(L"=================================\n\n");

    // Pequeña pausa para que el usuario vea el mensaje
    gBS->Stall(1000000); // 1 segundo

    // 7. ¡ARRANCAR EL KERNEL!
    Status = gBS->StartImage(
        KernelHandle,
        NULL,                     // ExitDataSize
        NULL                      // ExitData
    );

    // Si llegamos aquí, el kernel falló o retornó
    Print(L"\nEl kernel retornó con status: %r\n", Status);

    // Cleanup
    if (InitrdBuffer != NULL) {
        FreePool(InitrdBuffer);
    }

    gBS->UnloadImage(KernelHandle);

    return Status;
}

EFI_STATUS
LoadInitrdFile(
    IN  EFI_HANDLE DeviceHandle,
    IN  CHAR16     *Path,
    OUT VOID       **Buffer,
    OUT UINTN      *Size
)
{
    EFI_STATUS Status;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *FileSystem;
    EFI_FILE_PROTOCOL *Root;
    EFI_FILE_PROTOCOL *File;
    EFI_FILE_INFO *FileInfo;
    UINTN InfoSize;

    Status = gBS->HandleProtocol(
        DeviceHandle,
        &gEfiSimpleFileSystemProtocolGuid,
        (VOID **)&FileSystem
    );
    if (EFI_ERROR(Status)) return Status;

    Status = FileSystem->OpenVolume(FileSystem, &Root);
    if (EFI_ERROR(Status)) return Status;

    Status = Root->Open(Root, &File, Path, EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(Status)) {
        Root->Close(Root);
        return Status;
    }

    // Obtener tamaño del archivo
    InfoSize = SIZE_OF_EFI_FILE_INFO + 200;
    FileInfo = AllocatePool(InfoSize);
    Status = File->GetInfo(File, &gEfiFileInfoGuid, &InfoSize, FileInfo);
    if (EFI_ERROR(Status)) {
        File->Close(File);
        Root->Close(Root);
        FreePool(FileInfo);
        return Status;
    }

    *Size = (UINTN)FileInfo->FileSize;
    FreePool(FileInfo);

    // Leer archivo
    *Buffer = AllocatePool(*Size);
    if (*Buffer == NULL) {
        File->Close(File);
        Root->Close(Root);
        return EFI_OUT_OF_RESOURCES;
    }

    Status = File->Read(File, Size, *Buffer);

    File->Close(File);
    Root->Close(Root);

    return Status;
}

EFI_STATUS
InstallInitrdProtocol(
    IN VOID  *InitrdBuffer,
    IN UINTN InitrdSize
)
{
    //EFI_STATUS Status;
    //EFI_HANDLE Handle = NULL;

    // Crear un Load File Protocol para el initrd
    // (implementación simplificada, el kernel lo buscará)

    // Nota: Para una implementación completa necesitas crear
    // un EFI_LOAD_FILE2_PROTOCOL que devuelva el initrd.
    // Por simplicidad, muchos bootloaders solo ponen el initrd
    // en memoria y el kernel lo encuentra via command line o tables.

    // Alternativamente, pasar initrd via command line:
    // "initrd=0xADDRESS,SIZE"

    return EFI_SUCCESS;
}
// ***************************************************************************
// END: IMPLEMENTACIONES DE FUNCIONES.
// ***************************************************************************
