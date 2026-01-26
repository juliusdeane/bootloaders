#include <efi.h>
#include <efilib.h>


//****************************************************************************
// IP4_CONFIG2
// - definimos manualmente el GUID del protocolo IP4_CONFIG2
// - {5B446ED1-E30B-4FAA-871A-3654ECA36080}
//****************************************************************************
static EFI_GUID Ip4Config2ProtocolGuid = {
    0x5b446ed1, 0xe30b, 0x4faa,
    {0x87, 0x1a, 0x36, 0x54, 0xec, 0xa3, 0x60, 0x80}
};

// Tipo de datos para InterfaceInfo
#define Ip4Config2DataTypeInterfaceInfo 0

// Estructura de la interfaz IP4
typedef struct {
    CHAR16            Name[32];
    UINT8             IfType;
    UINT32            HwAddressSize;
    EFI_MAC_ADDRESS   HwAddress;
    EFI_IPv4_ADDRESS  StationAddress;
    EFI_IPv4_ADDRESS  SubnetMask;
    UINT32            RouteTableSize;
    VOID              *RouteTable;
} EFI_IP4_CONFIG2_INTERFACE_INFO;


// Estructura para el protocolo IP4_CONFIG2
typedef struct _EFI_IP4_CONFIG2_PROTOCOL {
    EFI_STATUS (EFIAPI *SetData)(
        struct _EFI_IP4_CONFIG2_PROTOCOL  *This,
        UINTN                             DataType,
        UINTN                             DataSize,
        VOID                              *Data
    );
    EFI_STATUS (EFIAPI *GetData)(
        struct _EFI_IP4_CONFIG2_PROTOCOL  *This,
        UINTN                             DataType,
        UINTN                             *DataSize,
        VOID                              *Data
    );
    EFI_STATUS (EFIAPI *RegisterDataNotify)(
        struct _EFI_IP4_CONFIG2_PROTOCOL  *This,
        UINTN                             DataType,
        EFI_EVENT                         Event
    );
    EFI_STATUS (EFIAPI *UnregisterDataNotify)(
        struct _EFI_IP4_CONFIG2_PROTOCOL  *This,
        UINTN                             DataType,
        EFI_EVENT                         Event
    );
} EFI_IP4_CONFIG2_PROTOCOL;


EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_STATUS                      Status;
    EFI_IP4_CONFIG2_PROTOCOL        *Ip4Config2;
    EFI_IP4_CONFIG2_INTERFACE_INFO  *IfInfo;
    UINTN                           DataSize;

    // Recuerda que gnu-efi requiere inicializar la librería:
    InitializeLib(ImageHandle, SystemTable);

    // Obtenemos el protocolo IP4_CONFIG2
    Status = uefi_call_wrapper(BS->LocateProtocol,
                               3,
                               &Ip4Config2ProtocolGuid,
                               NULL,
                               (VOID **)&Ip4Config2);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR] No se pudo localizar IP4_CONFIG2_PROTOCOL.\n");
        return Status;
    }

    // Tamaño de los datos
    DataSize = 0;
    Status = uefi_call_wrapper(Ip4Config2->GetData,
                               4,
                               Ip4Config2,
                               Ip4Config2DataTypeInterfaceInfo,
                               &DataSize,
                               NULL);

    if (Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"[ERROR] No puedo obtener DataSize.\n");
        return Status;
    }

    // Asignar memoria
    Status = uefi_call_wrapper(BS->AllocatePool,
                               3,
                               EfiLoaderData,
                               DataSize,
                               (VOID **)&IfInfo);

    if (EFI_ERROR(Status) || IfInfo == NULL) {
        Print(L"[ERROR] No puedo asignar memoria.\n");
        return EFI_OUT_OF_RESOURCES;
    }

    // Obtener información de la interfaz
    Status = uefi_call_wrapper(Ip4Config2->GetData,
                               4,
                               Ip4Config2,
                               Ip4Config2DataTypeInterfaceInfo,
                               &DataSize,
                               IfInfo);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR] No puedo obtener detalles del interfaz.\n");
        uefi_call_wrapper(BS->FreePool, 1, IfInfo);
        return Status;
    }

    // Mostrar dirección IP
    Print(L"IP: %d.%d.%d.%d | ",
          IfInfo->StationAddress.Addr[0],
          IfInfo->StationAddress.Addr[1],
          IfInfo->StationAddress.Addr[2],
          IfInfo->StationAddress.Addr[3]);

    // Mostrar máscara de subred
    Print(L"Netmask: %d.%d.%d.%d\n",
          IfInfo->SubnetMask.Addr[0],
          IfInfo->SubnetMask.Addr[1],
          IfInfo->SubnetMask.Addr[2],
          IfInfo->SubnetMask.Addr[3]);

    uefi_call_wrapper(BS->FreePool, 1, IfInfo);

    return EFI_SUCCESS;
}
