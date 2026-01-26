#include <efi.h>
#include <efilib.h>
#include "tools.h"


#define KERNEL_CMDLINE  L"initrd=\\BOOT\\initrd.cmp " \
                         "rdinit=/init.sh " \
                         "console=tty0 console=ttyS0,115200 " \
                         "earlyprintk=efi"
#define KERNEL_PATH     L"\\BOOT\\vmlinuz"


EFI_STATUS efi_main(EFI_HANDLE        ImageHandle,
                    EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS                    Status;
    EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop;
    EFI_LOADED_IMAGE              *Self;
    EFI_HANDLE                    KernelHandle;
    EFI_DEVICE_PATH               *KernelPath;
	CHAR16                        *kernel_cmdline;
	UINTN                         cmdline_size;

    InitializeLib(ImageHandle, SystemTable);

    Print(L"===============================================================================\n");
    Print(L"KERNEL BOOT START:\n");
    Print(L"===============================================================================\n");

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

    // 2) Crear DevicePath apuntando al fichero del kernel.
    KernelPath = FileDevicePath(
        Self->DeviceHandle,
        KERNEL_PATH
    );

    // 3) LoadImage: cargamos la imagen del kernel y recuperamos un handle.
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
