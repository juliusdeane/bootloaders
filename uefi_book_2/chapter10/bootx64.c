#include <efi.h>
#include <efilib.h>
#include "tools.h"
#include "dos_pe.h"


#define KERNEL_CMDLINE  L"initrd=\\BOOT\\initrd.cmp " \
                         "rdinit=/init.sh " \
                         "console=tty0 console=ttyS0,115200 " \
                         "earlyprintk=efi"

#define KERNEL_PATH     L"\\BOOT\\vmlinuz"
#define INITRD_PATH     L"\\BOOT\\initrd.cmp"


//****************************************************************************
// EFI_MAIN:
//****************************************************************************
EFI_STATUS efi_main(EFI_HANDLE        ImageHandle,
                    EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS                       Status;
    EFI_TIME                         now;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL  *FileSystem;
    EFI_FILE                         *kernel_file;
    EFI_FILE                         *CurrentDriveRoot;
    EFI_FILE_INFO                    *FileInfo;
    UINTN                            FileInfoSize;

    EFI_GRAPHICS_OUTPUT_PROTOCOL     *Gop;
    EFI_LOADED_IMAGE                 *Self;
    EFI_HANDLE                       KernelHandle;
    EFI_DEVICE_PATH                  *KernelPath;
	CHAR16                           *kernel_cmdline;
	UINTN                            cmdline_size;

    InitializeLib(ImageHandle, SystemTable);

    // Borramos la pantalla como primer paso:
    // - en este ejemplo procesado Status, pero en los siguientes lo ignoraremos.
    Status = ClearScreen();
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'ClearScreen()': %r\n", Status);
        Halt_Execution();
    }

    // Primer texto en pantalla:
    Print(L"DETALLES EL ENTORNO DE ARRANQUE:\r\n");
    Print(L"==== Fecha y Hora ====\r\n");

    // 1) Obtener LoadedImage de ESTE loader
    // - puntero a nuestra aplicación EFI.
    Status = uefi_call_wrapper(BS->HandleProtocol, 3,
                               ImageHandle,
                               &LoadedImageProtocol,
                               (VOID **)&Self);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'HandleProtocol' para 'LoadedImageProtocol': %r\n", Status);
        Halt_Execution();
    }

    // 1bis) Obtenemos la hora/fecha:
    Status = uefi_call_wrapper(RT->GetTime, 2,
                               &now, NULL);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No puedo obtener 'now' :( => %r\r\n", Status);
        Halt_Execution();
    }

    Print(L"    - Timezone: %d | Daylight: %d \r\n", now.TimeZone,
                                                     now.Daylight);

    Print(L"    - %02d/%02d/%04d - %02d:%02d:%02d.%d\r\n", now.Day,
                                                           now.Month,
                                                           now.Year,
                                                           now.Hour,
                                                           now.Minute,
                                                           now.Second,
                                                           now.Nanosecond);

    // Comentado: el código que preparamos originalmente y que nos llevó a
    // detectar un posible problema en gnu-efi.
    // Print(L"    - %02hhu/%02hhu/%04hu - %02hhu:%02hhu:%02hhu.%u\r\n", now.Day,
    //                                                                   now.Month,
    //                                                                   now.Year,
    //                                                                   now.Hour,
    //                                                                   now.Minute,
    //                                                                   now.Second,
    //                                                                   now.Nanosecond);

    // Esperamos antes de mostrar más información:
    WaitForKey(L"\nPulsa una tecla para continuar...\n");
    // Limpiamos la pantalla de nuevo:
    ClearScreen();

    // Detalles de nuestro firmware:
    // typedef struct {
    //     EFI_TABLE_HEADER                 Hdr;
    //     CHAR16                           *FirmwareVendor;
    //     UINT32                           FirmwareRevision;
    //     EFI_HANDLE                       ConsoleInHandle;
    //     EFI_SIMPLE_TEXT_INPUT_PROTOCOL   *ConIn;
    //     EFI_HANDLE                       ConsoleOutHandle;
    //     EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL  *ConOut;
    //     EFI_HANDLE                       StandardErrorHandle;
    //     EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL  *StdErr;
    //     EFI_RUNTIME_SERVICES             *RuntimeServices;
    //     EFI_BOOT_SERVICES                *BootServices;
    //     UINTN                            NumberOfTableEntries;
    //     EFI_CONFIGURATION_TABLE          *ConfigurationTable;
    // } EFI_SYSTEM_TABLE;
    Print(L"==== BIOS/Firmware ====\r\n");
    Print(L"    - Fabricante del firmware:                   %s\r\n", ST->FirmwareVendor);
    Print(L"    - Firmware version/revision:                 0x%08x\r\n", ST->FirmwareRevision);

    Print(L"    - Tablas de config. de sistema disponibles:  %llu\r\n\n", ST->NumberOfTableEntries);
    Print(L"    - Tablas de config. de sistema:\r\n");
    for(UINTN i=0; i < ST->NumberOfTableEntries; i++) {
        Print(L"        [%llu] GUID: %08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\r\n",
                i,
                ST->ConfigurationTable[i].VendorGuid.Data1,
                ST->ConfigurationTable[i].VendorGuid.Data2,
                ST->ConfigurationTable[i].VendorGuid.Data3,
                ST->ConfigurationTable[i].VendorGuid.Data4[0],
                ST->ConfigurationTable[i].VendorGuid.Data4[1],
                ST->ConfigurationTable[i].VendorGuid.Data4[2],
                ST->ConfigurationTable[i].VendorGuid.Data4[3],
                ST->ConfigurationTable[i].VendorGuid.Data4[4],
                ST->ConfigurationTable[i].VendorGuid.Data4[5],
                ST->ConfigurationTable[i].VendorGuid.Data4[6],
                ST->ConfigurationTable[i].VendorGuid.Data4[7]);
    }
    // Salto de línea:
    Print(L"\r\n");

    // Esperamos antes de mostrar más información:
    WaitForKey(L"\nPulsa una tecla para continuar...\n");
    ClearScreen();

    Print(L"==== Detalles del binario del KERNEL ====\r\n");
    Print(L"\r\n");

    // 2) Crear DevicePath apuntando al fichero del kernel.
    KernelPath = FileDevicePath(
        Self->DeviceHandle,
        KERNEL_PATH
    );

    Status = uefi_call_wrapper(BS->OpenProtocol, 6,
                               Self->DeviceHandle,
                               &FileSystemProtocol,
                               (void**)&FileSystem,
                               ImageHandle,
                               NULL,
                               EFI_OPEN_PROTOCOL_GET_PROTOCOL);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no podemos usar 'FileSystem OpenProtocol' => %r\r\n", Status);
        Halt_Execution();
    }

    Status = uefi_call_wrapper(FileSystem->OpenVolume, 2,
                               FileSystem, &CurrentDriveRoot);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'OpenVolume' => %r\r\n", Status);
        Halt_Execution();
    }

    Status = uefi_call_wrapper(CurrentDriveRoot->Open, 5,
                               CurrentDriveRoot,
                               &kernel_file,
                               KERNEL_PATH,
                               EFI_FILE_MODE_READ,
                               EFI_FILE_READ_ONLY);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: no puedo abrir el kernel [%s] => %r\r\n",
                                                   KERNEL_PATH,
                                                   Status);
        Halt_Execution();
    }
    CHAR16 * BootFilePath = ((FILEPATH_DEVICE_PATH*)Self->FilePath)->PathName;
    Print(L"    - BootFilePath=[%s]\r\n", BootFilePath);

    Status = uefi_call_wrapper(kernel_file->GetInfo, 4,
                               kernel_file,
                               &gEfiFileInfoGuid,
                               &FileInfoSize,
                               NULL);

    Print(L"    - KERNEL FileInfoSize: %llu bytes.\r\n", FileInfoSize);

    if(FileInfoSize <= 0) {
        Print(L"[ERROR]: 'GetInfo' da un size=0 (o menor) para kernel file => %d\r\n", FileInfoSize);
        Halt_Execution();
    }

    Status = uefi_call_wrapper(BS->AllocatePool, 3,
                               EfiLoaderData, FileInfoSize, (void**)&FileInfo);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'AllocatePool' para FileInfo => 0x%llx\r\n", Status);
        Halt_Execution();
    }

    Status = uefi_call_wrapper(kernel_file->GetInfo, 4,
                               kernel_file, &gEfiFileInfoGuid, &FileInfoSize, FileInfo);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'GetInfo' => 0x%llx\r\n", Status);
        Halt_Execution();
    }

    Print(L"    - FileName:       %s\r\n", FileInfo->FileName);
    Print(L"    - FileInfo size:  %llu\r\n", FileInfo->Size);
    Print(L"    - FILE size:      %llu\r\n", FileInfo->FileSize);
    Print(L"    - PhysicalSize:   %llu\r\n", FileInfo->PhysicalSize);
    Print(L"    - Atributo:       %llx\r\n", FileInfo->Attribute);
    Print(L"    - Created:        %02d/%02d/%04d - %02d:%02d:%02d.%d\r\n",
                                  FileInfo->CreateTime.Day,
                                  FileInfo->CreateTime.Month,
                                  FileInfo->CreateTime.Year,
                                  FileInfo->CreateTime.Hour,
                                  FileInfo->CreateTime.Minute,
                                  FileInfo->CreateTime.Second,
                                  FileInfo->CreateTime.Nanosecond);
    Print(L"    - Last Modified:  %02d/%02d/%04d - %02d:%02d:%02d.%d\r\n",
                                  FileInfo->ModificationTime.Day,
                                  FileInfo->ModificationTime.Month,
                                  FileInfo->ModificationTime.Year,
                                  FileInfo->ModificationTime.Hour,
                                  FileInfo->ModificationTime.Minute,
                                  FileInfo->ModificationTime.Second,
                                  FileInfo->ModificationTime.Nanosecond);

    // Esperamos una tecla para ir a las validaciones del formato PE:
    WaitForKey(L"\nPulsa una tecla para continuar...\n");
    ClearScreen();

    //************************************************************************
    // Verificaciones de la cabecera PE32+
    //************************************************************************
    Print(L"==== Detalles del formato PE32+ ====\r\n");
    IMAGE_DOS_HEADER DOSheader;
    UINTN size = sizeof(IMAGE_DOS_HEADER);
    Status = uefi_call_wrapper(kernel_file->Read, 3,
                               kernel_file, &size, &DOSheader);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error leyendo 'DOSheader' => 0x%llx\r\n", Status);
        Halt_Execution();
    }

    // Si !MZ, error.
    if(DOSheader.e_magic != 0x5A4D) {
        Print(L"[ERROR]: 'DOSheader.e_magic' != 'MZ' => ¿no es un PE? => 0x%x\r\n", DOSheader.e_magic);
        Halt_Execution();
    }
    Print(L"    - DOSheader           => 'MZ' == 0x%x [OK]\r\n", DOSheader.e_magic);
    Print(L"    - DOSheader.e_lfanew  => 0x%x\r\n", DOSheader.e_lfanew);

    // PE Header ->
    Status = uefi_call_wrapper(kernel_file->SetPosition, 2,
                               kernel_file, (UINT64)DOSheader.e_lfanew);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'SetPosition' => 0x%llx\r\n", Status);
        Halt_Execution();
    }

    IMAGE_NT_HEADERS64 PEHeader;
    Status = uefi_call_wrapper(kernel_file->Read, 3,
                               kernel_file, &size, &PEHeader);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error leyendo 'PE header' => 0x%llx\r\n", Status);
        Halt_Execution();
    }

    // 'PE'
    if(PEHeader.Signature != 0x4550) {
        Print(L"[ERROR]: PEHeader.Signature != 0x4550 => 0x%x\r\n", PEHeader.Signature);
        Halt_Execution();
    }
    Print(L"    - PE Header Signature => 'PE' == 0x4550 [OK]\r\n");

    // PE Headers have Signature, FileHeader, and OptionalHeader
    // - https://github.com/tianocore/edk2/blob/master/MdePkg/Include/IndustryStandard/PeImage.h
    if(PEHeader.FileHeader.Machine != IMAGE_FILE_MACHINE_X64) {
        Print(L"[ERROR]: PEHeader.FileHeader.Machine != IMAGE_FILE_MACHINE_X64 => 0x%x\r\n", PEHeader.FileHeader.Machine);
        Halt_Execution();
    }
    Print(L"    - PEHeader.FileHeader.Machine == IMAGE_FILE_MACHINE_X64 [OK]\r\n");

    if(PEHeader.OptionalHeader.Magic != EFI_IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
        Print(L"[ERROR]: PEHeader.OptionalHeader.Magic != EFI_IMAGE_NT_OPTIONAL_HDR64_MAGIC => 0x%x\r\n", PEHeader.OptionalHeader.Magic);
        Halt_Execution();
    }
    Print(L"    - PEHeader.OptionalHeader.Magic == EFI_IMAGE_NT_OPTIONAL_HDR64_MAGIC [OK]\r\n");

    // Última comprobación:
    // - compilado con: -Wl,--subsystem,10
    if (PEHeader.OptionalHeader.Subsystem != IMAGE_SUBSYSTEM_EFI_APPLICATION) {
        // If it's 3, it was compiled as a Windows CUI (command line) program, and instead needs to be linked with the above GCC flag.
        Print(L"\n[AVISO] Puede no ser una aplic. UEFI PE32+ correcta :-?\r\n");
        Print(L"    - Subsystem: %hu\r\n", PEHeader.OptionalHeader.Subsystem);
    }

    // 3) LoadImage: cargamos la imagen del kernel y recuperamos un handle.
    Print(L"\r\n*****> A partir de aquí cargaremos la imagen del kernel con 'LoadImage':\r\n");
    Status = uefi_call_wrapper(BS->LoadImage, 6,
                               FALSE,
                               ImageHandle,
                               KernelPath,
                               NULL,
                               0,
                               &KernelHandle);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'LoadImage': %r\n", Status);
        Halt_Execution();
    }

    // 4) LoadedImage del kernel: KernelImage.
    EFI_LOADED_IMAGE *KernelImage;
    Status = uefi_call_wrapper(BS->HandleProtocol, 3,
                               KernelHandle,
                               &LoadedImageProtocol,
                               (VOID **)&KernelImage);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'Kernel HandleProtocol': %r\n", Status);
        Halt_Execution();
    }

	// pre-5) Preparamos la kernel command line.
	cmdline_size = StrLen(KERNEL_CMDLINE) + 1;
	kernel_cmdline = AllocatePool(cmdline_size * sizeof(CHAR16));
	ZeroMem(kernel_cmdline, cmdline_size * sizeof(CHAR16));
	StrCpy(kernel_cmdline, KERNEL_CMDLINE);

    // 5. Pasar cmdline: la kernel cmdline.
    KernelImage->LoadOptions     = kernel_cmdline;
    KernelImage->LoadOptionsSize = cmdline_size;

    // Esperamos una tecla ANTES de configurar GOP:
    WaitForKey(L"\nPulsa una tecla para cargar [kernel+initrd] y transferirles el control...\n");

    // 6) Localizar GOP: EXTREMADAMENTE importante.
    // - Graphics Output Protocol (GOP).
    Status = uefi_call_wrapper(BS->LocateProtocol, 3,
                               &gEfiGraphicsOutputProtocolGuid,
                               NULL,
                               (VOID **)&Gop);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'gEfiGraphicsOutputProtocolGuid': %r\n", Status);
        Halt_Execution();
    }

    // 6bis) Forzar modo actual (importante)
    Status = uefi_call_wrapper(Gop->SetMode, 2,
                               Gop, Gop->Mode->Mode);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'Gop->SetMode': %r\n", Status);
        Halt_Execution();
    }

    // Colocamos el cursor en la parte superior:
    SetCursorPosition(0, 0);

    // 7) Arrancar con StartImage usando el KernelHandle.
    Status = uefi_call_wrapper(BS->StartImage, 3,
                               KernelHandle, NULL, NULL);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: fallo en 'StartImage': %r\n", Status);
		Halt_Execution();
    }

	// Nunca debe llegar hasta este punto.
	Halt_Execution();
    return EFI_SUCCESS;
}
//****************************************************************************
// FIN: EFI_MAIN.
//****************************************************************************
