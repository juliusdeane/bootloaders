#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>

// Para ver detalles de un handle.
#include <Protocol/DevicePath.h>
#include <Protocol/DevicePathToText.h>
//****************************************************************************
// NETWORK:
//****************************************************************************
// SimpleNetwork: para obtener el listado de interfaces de red.
//****************************************************************************
#include <Protocol/SimpleNetwork.h>


EFI_STATUS EnumerateInterfaces(OUT EFI_HANDLE **Handles, OUT UINTN *HandleCount);
EFI_STATUS GetDevicePathFromHandle(IN EFI_HANDLE Handle, OUT EFI_DEVICE_PATH_PROTOCOL **DevicePath);
EFI_STATUS DevicePathToText(IN EFI_DEVICE_PATH_PROTOCOL *DevicePath, OUT CHAR16 **TextPath);

//****************************************************************************
// UEFIMAIN:
//****************************************************************************
EFI_STATUS
EFIAPI
UefiMain(IN EFI_HANDLE ImageHandle,IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS Status;
    EFI_HANDLE *Handles = NULL;
    UINTN HandleCount = 0;

    Print(L"\n");
    Status = EnumerateInterfaces(&Handles, &HandleCount);

    if(EFI_ERROR(Status)) {
        Print(L"[UefiMain] No se han encontrado interfaces de red.\n");
        return Status;
    }

    if(EFI_ERROR(Status)) {
        Print(L"[UefiMain] No se pudo obtener DevicePathToText.\n");
        return Status;
    }

    Print(L"[UefiMain] Interfaces de red encontrados:\n");
    Print(L"=========================================\n");
    for(UINTN i = 0; i < HandleCount; i++) {
        EFI_DEVICE_PATH_PROTOCOL  *D = NULL;
        CHAR16                    *TextPath = NULL;

        GetDevicePathFromHandle(Handles[i], &D);
        DevicePathToText(D, &TextPath);

        Print(L"  - 0x%p (0x%p) | %s\n", Handles[i],
                                         D, TextPath);
    }
    Print(L"=========================================\n");
    return EFI_SUCCESS;
}
//****************************************************************************
// END UEFIMAIN.
// //****************************************************************************


EFI_STATUS EnumerateInterfaces(OUT EFI_HANDLE **Handles, OUT UINTN *HandleCount) {
    EFI_STATUS Status;
    Status = gBS->LocateHandleBuffer(ByProtocol,
                                     &gEfiSimpleNetworkProtocolGuid,
                                     NULL,
                                     HandleCount,
                                     Handles);
    if(EFI_ERROR(Status)) {
        Print(L"ERROR: No se han encontrado interfaces de red.\n");
        return Status;
    }

    return EFI_SUCCESS;
}

EFI_STATUS GetDevicePathFromHandle(IN EFI_HANDLE Handle, OUT EFI_DEVICE_PATH_PROTOCOL **DevicePath) {
    return gBS->OpenProtocol(Handle,
                             &gEfiDevicePathProtocolGuid,
                             (VOID **) DevicePath,
                             gImageHandle,
                             NULL,
                             EFI_OPEN_PROTOCOL_GET_PROTOCOL);
}


EFI_STATUS DevicePathToText(IN EFI_DEVICE_PATH_PROTOCOL *DevicePath, OUT CHAR16 **TextPath) {
    EFI_STATUS                        Status;
    EFI_DEVICE_PATH_TO_TEXT_PROTOCOL  *DevicePathToText = NULL;

    Status = gBS->LocateProtocol(&gEfiDevicePathToTextProtocolGuid,
                                 NULL,
                                 (VOID **)&DevicePathToText);
    if (EFI_ERROR(Status)) {
        return Status;
    }

    *TextPath = DevicePathToText->ConvertDevicePathToText(DevicePath, TRUE, TRUE);
    if (*TextPath == NULL) {
        return EFI_OUT_OF_RESOURCES;
    }

    return EFI_SUCCESS;
}
