#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Protocol/Ip4Config2.h>


EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  ) {
    EFI_STATUS                      Status;
    EFI_IP4_CONFIG2_PROTOCOL        *Ip4Config2;
    EFI_IP4_CONFIG2_INTERFACE_INFO  *IfInfo;
    UINTN                           DataSize;

    // Localizamos el protocolo IP4_CONFIG2
    Status = gBS->LocateProtocol(
                    &gEfiIp4Config2ProtocolGuid,
                    NULL,
                    (VOID **)&Ip4Config2
                    );

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: No se pudo localizar IP4_CONFIG2_PROTOCOL.\n");
        return Status;
    }

    // Obtenemos el tamaño de los datos
    DataSize = 0;
    Status = Ip4Config2->GetData(
                           Ip4Config2,
                           Ip4Config2DataTypeInterfaceInfo,
                           &DataSize,
                           NULL
                           );

    if (Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"[ERROR] [UefiMain]: no puedo obtener DataSize.\n");
        return Status;
    }

    // Asignamos memoria
    IfInfo = AllocatePool(DataSize);
    if (IfInfo == NULL) {
        Print(L"[ERROR] [UefiMain]: no puedo asignar memoria.\n");
        return EFI_OUT_OF_RESOURCES;
    }

    // Información de la interfaz
    Status = Ip4Config2->GetData(
                           Ip4Config2,
                           Ip4Config2DataTypeInterfaceInfo,
                           &DataSize,
                           IfInfo
                           );

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: no puedo obtener detalles del interfaz.\n");
        FreePool(IfInfo);
        return Status;
    }

    // Dirección IP:
    Print(L"IP: %d.%d.%d.%d | ",
          IfInfo->StationAddress.Addr[0],
          IfInfo->StationAddress.Addr[1],
          IfInfo->StationAddress.Addr[2],
          IfInfo->StationAddress.Addr[3]);

    // + máscara de subred
    Print(L"Netmask: %d.%d.%d.%d\n",
          IfInfo->SubnetMask.Addr[0],
          IfInfo->SubnetMask.Addr[1],
          IfInfo->SubnetMask.Addr[2],
          IfInfo->SubnetMask.Addr[3]);

    FreePool(IfInfo);

    return EFI_SUCCESS;
}
