#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>

#include <Library/BaseMemoryLib.h>
#include <Library/MemoryAllocationLib.h>

#include <Protocol/Tcp4.h>
#include <Protocol/Ip4Config2.h>

#include <Protocol/ServiceBinding.h>
#include <Protocol/ShellParameters.h>

// Para generar aleatorios:
#include <Protocol/Rng.h>


#define EHLO_MESSAGE               "Hola, he conectado TCP4 y te digo 'hola' al estilo SMTP :)\n"
#define EXPECTED_RESPONSE_MESSAGE  "250-mx.uefi.int fingiendo ser un servidor SMTP"


// Variables globales
EFI_TCP4_PROTOCOL                  *mTcp4Protocol = NULL;
EFI_HANDLE                         mTcp4ChildHandle = NULL;
EFI_SERVICE_BINDING_PROTOCOL       *mServiceBinding = NULL;


// Nuestra propia clase IP_ADDRESS:
typedef struct {
    UINT8 Octet[4];
} IP_ADDRESS;


STATIC UINTN StringToINTN(IN CHAR16 *String);
EFI_STATUS ParseIpAddress(IN  CHAR16      *IpString,
                          OUT IP_ADDRESS  *IpAddress);

// El proceso de callbacks en TCP4 es más complejo:
VOID EFIAPI ConnectCallback(IN EFI_EVENT  Event,
                            IN VOID       *Context);
VOID EFIAPI TransmitCallback(IN EFI_EVENT  Event,
                             IN VOID       *Context);
VOID EFIAPI ReceiveCallback(IN EFI_EVENT  Event,
                            IN VOID       *Context);
VOID EFIAPI CloseCallback(IN EFI_EVENT  Event,
                          IN VOID       *Context);

EFI_STATUS InitializeTcp4Protocol(VOID);

VOID CleanupTcp4Protocol(VOID);

EFI_STATUS ConnectToServer(IN EFI_IPv4_ADDRESS  *ServerAddress,
                           IN UINT16            ServerPort);

EFI_STATUS SendTcpData(IN UINT8   *Data,
                       IN UINTN   DataLength);

EFI_STATUS ReceiveTcpData(IN UINT32  TimeoutMs,
                          OUT UINT8  **ReceivedData,
                          OUT UINTN  *ReceivedLength);

EFI_STATUS CloseTcpConnection(VOID);


EFI_STATUS EFIAPI UefiMain(IN EFI_HANDLE        ImageHandle,
                           IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS                      Status;
    EFI_IP4_CONFIG2_PROTOCOL        *Ip4Config2;
    EFI_IP4_CONFIG2_INTERFACE_INFO  *IfInfo;
    UINTN                           DataSize;
    EFI_SHELL_PARAMETERS_PROTOCOL   *ShellArguments;
    UINTN                           Argc = 0;
    IP_ADDRESS                      argumentIP;
    EFI_IPv4_ADDRESS                ServerAddress;
    UINT16                          ServerPort;
    UINT8                           *ReceivedData;
    UINTN                           ReceivedLength;

    // Obtener el protocolo de parámetros del shell
    Status = gBS->OpenProtocol (ImageHandle,
                                &gEfiShellParametersProtocolGuid,
                                (VOID **)&ShellArguments,
                                ImageHandle,
                                NULL,
                                EFI_OPEN_PROTOCOL_GET_PROTOCOL);

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: no se han podido obtener los argumentos :( => %r.\n", Status);
        return Status;
    }

    // Mostrar los argumentos
    Argc = ShellArguments->Argc;
    Print(L"[OK] Total de argumentos (Argc): %d\n", Argc);
    for (UINTN Index = 0; Index < Argc; Index++) {
        Print(L"    - Argv[%d]: %s\n", Index, ShellArguments->Argv[Index]);
    }

    // Necesitamos IP y puerto: TcpConnect.efi 192.168.1.100 8080
    if (Argc == 3) {
        Status = ParseIpAddress(ShellArguments->Argv[1], &argumentIP);
        if (EFI_ERROR(Status)) {
            Print(L"[ERROR] [UefiMain]: no se han podido parsear la IP [%s] :( => %r.\n",
                  ShellArguments->Argv[1], Status);
            return Status;
        }

        ServerPort = (UINT16)StringToINTN(ShellArguments->Argv[2]);
        if (ServerPort == 0) {
            Print(L"[ERROR] [UefiMain]: puerto inválido [%s].\n", ShellArguments->Argv[2]);
            return EFI_INVALID_PARAMETER;
        }
    }
    else {
        Print(L"[ERROR]: uso: TcpConnect.efi <IP> <PUERTO>\n");
        Print(L"    Ejemplo: TcpConnect.efi 192.168.1.100 8080\n");
        return EFI_INVALID_PARAMETER;
    }

    // Convertir a EFI_IPv4_ADDRESS
    ServerAddress.Addr[0] = argumentIP.Octet[0];
    ServerAddress.Addr[1] = argumentIP.Octet[1];
    ServerAddress.Addr[2] = argumentIP.Octet[2];
    ServerAddress.Addr[3] = argumentIP.Octet[3];

    Print(L"[OK] Conectando a [%d.%d.%d.%d:%d]:\n",
          ServerAddress.Addr[0],
          ServerAddress.Addr[1],
          ServerAddress.Addr[2],
          ServerAddress.Addr[3],
          ServerPort);

    // Localizamos el protocolo IP4_CONFIG2 (para mostrar info de interfaz)
    Status = gBS->LocateProtocol(
                    &gEfiIp4Config2ProtocolGuid,
                    NULL,
                    (VOID **)&Ip4Config2
                    );

    if (EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: No se pudo localizar IP4_CONFIG2_PROTOCOL.\n");
        return Status;
    }

    // Obtenemos el tamaño de los datos con GetData:
    DataSize = 0;
    Status = Ip4Config2->GetData(Ip4Config2,
                                 Ip4Config2DataTypeInterfaceInfo,
                                 &DataSize,
                                 NULL);

    if (Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"[ERROR] [UefiMain]: no puedo obtener 'DataSize'.\n");
        return Status;
    }

    // Asignamos memoria
    IfInfo = AllocatePool(DataSize);
    if (IfInfo == NULL) {
        Print(L"[ERROR] [UefiMain]: no puedo asignar memoria.\n");
        return EFI_OUT_OF_RESOURCES;
    }

    // Información de la interfaz
    Status = Ip4Config2->GetData(Ip4Config2,
                                 Ip4Config2DataTypeInterfaceInfo,
                                 &DataSize,
                                 IfInfo);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: no puedo obtener detalles del interfaz :( => %r\n", Status);
        FreePool(IfInfo);
        return Status;
    }

    // Dirección IP: al estilo Ip4Config2.
    Print(L"IP Local: %d.%d.%d.%d | ",
          IfInfo->StationAddress.Addr[0],
          IfInfo->StationAddress.Addr[1],
          IfInfo->StationAddress.Addr[2],
          IfInfo->StationAddress.Addr[3]);

    // + máscara de subred
    Print(L"Netmask: %d.%d.%d.%d\n\n",
          IfInfo->SubnetMask.Addr[0],
          IfInfo->SubnetMask.Addr[1],
          IfInfo->SubnetMask.Addr[2],
          IfInfo->SubnetMask.Addr[3]);

    //************************************************************************
    // TCP: empieza aquí...
    //************************************************************************
    Status = InitializeTcp4Protocol();
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo inicializar TCP4 Protocol :( => %r\n", Status);
        FreePool(IfInfo);
        return Status;
    }

    // Conectar al servidor
    Status = ConnectToServer(&ServerAddress, ServerPort);
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo conectar al servidor :( => %r\n", Status);
        CleanupTcp4Protocol();
        FreePool(IfInfo);
        return Status;
    }

    Print(L"[OK] TCP4 connection establecida!\n\n");

    // Enviar mensaje EHLO:
    Print(L"[!!!] Enviando mensaje:\n");
    Status = SendTcpData((UINT8 *)EHLO_MESSAGE, AsciiStrLen(EHLO_MESSAGE));
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo enviar datos :( => %r\n", Status);
        CleanupTcp4Protocol();
        FreePool(IfInfo);
        return Status;
    }

    // Recibimos respuesta: asíncrona, claro.
    Print(L"[!!!] Esperando respuesta del servidor...\n");
    Status = ReceiveTcpData(10000, &ReceivedData, &ReceivedLength);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo recibir datos :( => %r\n", Status);
        CleanupTcp4Protocol();
        FreePool(IfInfo);
        return Status;
    }

    Print(L"[OK] Datos recibidos: %d bytes\n", ReceivedLength);

    // Mostramos los primeros caracteres (limitado a 256)
    UINTN PrintLen = (ReceivedLength > 256) ? 256 : ReceivedLength;
    Print(L"\n----- Inicio de respuesta -----\n");
    for(UINTN i = 0; i < PrintLen; i++) {
        Print(L"%c", (CHAR16)ReceivedData[i]);
    }
    if(ReceivedLength > 256) {
        Print(L"\n... (truncado) ...");
    }
    Print(L"\n----- Fin de respuesta -----\n\n");

    FreePool(ReceivedData);

    // Cerrar conexión
    Print(L"Cerrando TCP4...\n");
    Status = CloseTcpConnection();
    if (!EFI_ERROR (Status)) {
        Print(L"[OK] TCP4 connection cerrada correctamente\n");
    }

    CleanupTcp4Protocol();
    //************************************************************************
    // END TCP.
    //************************************************************************

    // Liberar recursos:
    FreePool(IfInfo);
    return EFI_SUCCESS;
}


STATIC UINTN StringToINTN(IN CHAR16 *String) {
    UINTN Result = 0;

    while (*String >= L'0' && *String <= L'9') {
        Result = Result * 10 + (*String - L'0');
        String++;
    }

    return Result;
}


EFI_STATUS ParseIpAddress(IN  CHAR16      *IpString,
                          OUT IP_ADDRESS  *IpAddress) {
    CHAR16   TempBuffer[4];
    UINTN    OctetIndex = 0;
    UINTN    BufferIndex = 0;
    UINTN    Value;
    CHAR16   *Ptr = IpString;

    if (IpString == NULL || IpAddress == NULL) {
        return EFI_INVALID_PARAMETER;
    }

    ZeroMem(IpAddress, sizeof(IP_ADDRESS));
    ZeroMem(TempBuffer, sizeof(TempBuffer));

    while (*Ptr != L'\0' && OctetIndex < 4) {
        if (*Ptr >= L'0' && *Ptr <= L'9') {
            // Acumular dígitos
            if (BufferIndex < 3) {
                TempBuffer[BufferIndex++] = *Ptr;
            } else {
                return EFI_INVALID_PARAMETER; // Octeto demasiado largo
            }
        } else if (*Ptr == L'.') {
            // Procesar octeto
            if (BufferIndex == 0) {
                return EFI_INVALID_PARAMETER; // Octeto vacío
            }

            TempBuffer[BufferIndex] = L'\0';
            Value = StringToINTN(TempBuffer);

            if (Value > 255) {
                return EFI_INVALID_PARAMETER; // Valor fuera de rango
            }

            IpAddress->Octet[OctetIndex++] = (UINT8)Value;

            // Reiniciar buffer para siguiente octeto
            BufferIndex = 0;
            ZeroMem(TempBuffer, sizeof(TempBuffer));
        } else {
            return EFI_INVALID_PARAMETER; // Carácter inválido
        }

        Ptr++;
    }

    // Procesar último octeto
    if (BufferIndex > 0 && OctetIndex == 3) {
        TempBuffer[BufferIndex] = L'\0';
        Value = StringToINTN(TempBuffer);

        if (Value > 255) {
            return EFI_INVALID_PARAMETER;
        }

        IpAddress->Octet[OctetIndex++] = (UINT8)Value;
    }

    // Verificar que tenemos 4 octetos
    if (OctetIndex != 4) {
        return EFI_INVALID_PARAMETER;
    }

    return EFI_SUCCESS;
}


VOID EFIAPI ConnectCallback(IN EFI_EVENT  Event,
                            IN VOID       *Context) {
    BOOLEAN *Done = (BOOLEAN *)Context;
    *Done = TRUE;
    Print(L"[ConnectCallback] [Callback]: connect completado:\n");
}


VOID EFIAPI TransmitCallback(IN EFI_EVENT  Event,
                             IN VOID       *Context) {
    BOOLEAN *Done = (BOOLEAN *)Context;
    *Done = TRUE;
    Print(L"[TransmitCallback] [Callback]: send completado:\n");
}


VOID EFIAPI ReceiveCallback(IN EFI_EVENT  Event,
                            IN VOID       *Context) {
    BOOLEAN *Done = (BOOLEAN *)Context;
    *Done = TRUE;
    Print(L"[Callback] Receive completado.\n");
}


VOID EFIAPI CloseCallback(IN EFI_EVENT  Event,
                          IN VOID       *Context) {
    BOOLEAN *Done = (BOOLEAN *)Context;
    *Done = TRUE;
    Print(L"[Callback] Close completado.\n");
}


EFI_STATUS InitializeTcp4Protocol(VOID) {
    EFI_STATUS  Status;
    UINTN       HandleCount;
    EFI_HANDLE  *HandleBuffer;
    UINTN       Index;

    // Buscar handles con TCP4 Service Binding Protocol
    Status = gBS->LocateHandleBuffer(ByProtocol,
                                     &gEfiTcp4ServiceBindingProtocolGuid,
                                     NULL,
                                     &HandleCount,
                                     &HandleBuffer);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se encontraron interfaces TCP4: %r\n", Status);
        return Status;
    }

    Print(L"[OK] Encontradas %d interfaces TCP4\n", HandleCount);

    // Usar la primera interfaz disponible
    for(Index = 0; Index < HandleCount; Index++) {
        Status = gBS->HandleProtocol(HandleBuffer[Index],
                                     &gEfiTcp4ServiceBindingProtocolGuid,
                                     (VOID **)&mServiceBinding);

        if(EFI_ERROR(Status)) {
            continue;
        }

        // Crear un hijo (instancia de TCP4)
        mTcp4ChildHandle = NULL;
        Status = mServiceBinding->CreateChild(mServiceBinding, &mTcp4ChildHandle);
        if(EFI_ERROR(Status)) {
            Print(L"[ERROR]: No se pudo crear hijo TCP4: %r\n", Status);
            continue;
        }

        // Obtener el protocolo TCP4
        Status = gBS->HandleProtocol(mTcp4ChildHandle,
                                     &gEfiTcp4ProtocolGuid,
                                     (VOID **)&mTcp4Protocol);

        if(EFI_ERROR(Status)) {
            Print(L"[ERROR]: No se pudo obtener TCP4 Protocol: %r\n", Status);
            mServiceBinding->DestroyChild(mServiceBinding, mTcp4ChildHandle);
            continue;
        }

        // Configurar el protocolo TCP4:
        // IMPORTANTE: NO lo configuramos aquí, lo haremos en ConnectToServer
        // porque necesitamos el puerto remoto primero.
        // TCP4 se puede dejar sin configurar inicialmente.
        // La configuración se hace en ConnectToServer() cuando tenemos
        // la dirección y puerto del servidor, ambos.

        FreePool(HandleBuffer);
        return EFI_SUCCESS;
    }

    FreePool(HandleBuffer);
    return EFI_NOT_FOUND;
}


VOID CleanupTcp4Protocol(VOID) {
    if (mTcp4Protocol != NULL) {
        mTcp4Protocol->Configure(mTcp4Protocol, NULL);
    }

    if (mServiceBinding != NULL && mTcp4ChildHandle != NULL) {
        mServiceBinding->DestroyChild(mServiceBinding, mTcp4ChildHandle);
    }
}


EFI_STATUS ConnectToServer(IN EFI_IPv4_ADDRESS  *ServerAddress,
                           IN UINT16            ServerPort) {
    EFI_STATUS                  Status;
    EFI_TCP4_CONNECTION_TOKEN   ConnectToken;
    BOOLEAN                     ConnectDone;
    UINT32                      TimeElapsed;
    UINT32                      TimeoutMs = 10000;  // 10 segundos

    Print(L"\n===== Iniciando TCP4 connect =====\n");
    Print(L"    - Servidor: %d.%d.%d.%d:%d\n",
                        ServerAddress->Addr[0],
                        ServerAddress->Addr[1],
                        ServerAddress->Addr[2],
                        ServerAddress->Addr[3],
                        ServerPort);

    // Configurar TCP4 con la dirección y puerto del servidor:
    EFI_TCP4_CONFIG_DATA   Tcp4ConfigData;
    EFI_TCP4_ACCESS_POINT  AccessPoint;

    ZeroMem(&Tcp4ConfigData, sizeof(Tcp4ConfigData));
    ZeroMem(&AccessPoint, sizeof(AccessPoint));

    // Configuramos primero el AccessPoint...
    AccessPoint.UseDefaultAddress = TRUE;              // Usar IP del sistema
    AccessPoint.StationPort = 0;                       // Puerto local automático
    AccessPoint.RemotePort = ServerPort;               // Puerto del servidor
    CopyMem(&AccessPoint.RemoteAddress, ServerAddress,
            sizeof(EFI_IPv4_ADDRESS));
    AccessPoint.ActiveFlag = TRUE;                     // Modo cliente (activo)

    // Ahora sí, configuramos TCP4 -> TCP4ConfigData
    Tcp4ConfigData.TypeOfService = 0;
    Tcp4ConfigData.TimeToLive = 64;
    Tcp4ConfigData.AccessPoint = AccessPoint;
    Tcp4ConfigData.ControlOption = NULL;

    // Configuramos el protocolo TCP4 -> mTcp4Protocol.
    Print(L"[...] Configurando TCP4...\n");
    Status = mTcp4Protocol->Configure(mTcp4Protocol, &Tcp4ConfigData);
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo configurar TCP4: %r\n", Status);
        return Status;
    }

    Print(L"[OK] TCP4 configurado correctamente:\n");

    // Preparar token de conexión (asíncrono):
    ZeroMem(&ConnectToken, sizeof(ConnectToken));
    // Nuestro flag que confirma que hemos llegado al callback.
    ConnectDone = FALSE;

    // Crear evento para conexión
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              ConnectCallback,
                              &ConnectDone,
                              &ConnectToken.CompletionToken.Event);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se ha podido crear 'EVT_NOTIFY_SIGNAL' :( => %r\n", Status);
        return Status;
    }

    // Preparamos el estado del token a "NO PREPARADO",
    // porque no la hemos completado todavía, claro...
    ConnectToken.CompletionToken.Status = EFI_NOT_READY;

    // Iniciar conexión TCP (el famoso three-way handshake):
    Print(L"[...] Iniciando three-way handshake TCP...\n");
    Status = mTcp4Protocol->Connect(mTcp4Protocol, &ConnectToken);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: Connect() falló: %r\n", Status);
        gBS->CloseEvent(ConnectToken.CompletionToken.Event);
        return Status;
    }

    Print(L"[...] Connection: esperando...\n");

    // Esperar conexión con timeout
    TimeElapsed = 0;
    while (!ConnectDone && TimeElapsed < TimeoutMs) {
        mTcp4Protocol->Poll(mTcp4Protocol);
        gBS->Stall(10000);  // 10ms
        TimeElapsed += 10;

        // Mostrar progreso cada segundo
        if (TimeElapsed % 1000 == 0) {
            Print(L"    ... [%d] segundos\n", TimeElapsed / 1000);
        }
    }

    if (!ConnectDone) {
        Print(L"[ERROR]: Timeout conectando al servidor!\n");
        mTcp4Protocol->Cancel(mTcp4Protocol, &ConnectToken.CompletionToken);
        gBS->CloseEvent(ConnectToken.CompletionToken.Event);
        return EFI_TIMEOUT;
    }

    // Verificar estado:
    if (EFI_ERROR(ConnectToken.CompletionToken.Status)) {
        Print(L"[ERROR]: error Connect: %r\n", ConnectToken.CompletionToken.Status);
        Status = ConnectToken.CompletionToken.Status;
    } else {
        Print(L"[OK] Conectado correctamente en [%d] ms:\n", TimeElapsed);
        Status = EFI_SUCCESS;
    }

    gBS->CloseEvent(ConnectToken.CompletionToken.Event);
    return Status;
}


EFI_STATUS SendTcpData(IN UINT8   *Data,
                       IN UINTN   DataLength) {
    EFI_STATUS              Status;
    EFI_TCP4_IO_TOKEN       TxToken;
    EFI_TCP4_TRANSMIT_DATA  TxData;
    EFI_TCP4_FRAGMENT_DATA  Fragment;
    BOOLEAN                 TxDone;
    UINT32                  TimeElapsed;
    UINT32                  TimeoutMs = 5000;

    Print(L"\n===== Enviando datos TCP =====\n");
    Print(L"    - Size: %d bytes\n", DataLength);

    ZeroMem(&TxToken, sizeof(TxToken));
    ZeroMem(&TxData, sizeof(TxData));
    ZeroMem(&Fragment, sizeof(Fragment));
    TxDone = FALSE;

    // Crear evento de transmisión
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              TransmitCallback,
                              &TxDone,
                              &TxToken.CompletionToken.Event);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear evento TX: %r\n", Status);
        return Status;
    }

    // Configurar datos de transmisión (TX):
    TxData.Push = TRUE;
    TxData.Urgent = FALSE;
    TxData.DataLength = (UINT32)DataLength;
    TxData.FragmentCount = 1;

    Fragment.FragmentLength = (UINT32)DataLength;
    Fragment.FragmentBuffer = Data;
    TxData.FragmentTable[0] = Fragment;

    TxToken.Packet.TxData = &TxData;
    TxToken.CompletionToken.Status = EFI_NOT_READY;

    // Transmitir
    Status = mTcp4Protocol->Transmit(mTcp4Protocol, &TxToken);
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: Transmit() falló: %r\n", Status);
        gBS->CloseEvent(TxToken.CompletionToken.Event);
        return Status;
    }

    // Esperar que se complete o salte por timeout:
    TimeElapsed = 0;
    while (!TxDone && TimeElapsed < TimeoutMs) {
        mTcp4Protocol->Poll(mTcp4Protocol);
        gBS->Stall(1000);
        TimeElapsed += 1;
    }

    if (!TxDone) {
        Print(L"[ERROR]: Timeout enviando datos\n");
        mTcp4Protocol->Cancel(mTcp4Protocol, &TxToken.CompletionToken);
        gBS->CloseEvent(TxToken.CompletionToken.Event);
        return EFI_TIMEOUT;
    }

    // Verificar resultado
    if (EFI_ERROR(TxToken.CompletionToken.Status)) {
        Print(L"[ERROR]: Transmisión falló: %r\n", TxToken.CompletionToken.Status);
        Status = TxToken.CompletionToken.Status;
    } else {
        Print(L"[OK] ✓ Datos enviados en %d ms\n", TimeElapsed);
        Status = EFI_SUCCESS;
    }

    gBS->CloseEvent(TxToken.CompletionToken.Event);
    return Status;
}


EFI_STATUS ReceiveTcpData(IN UINT32  TimeoutMs,
                          OUT UINT8  **ReceivedData,
                          OUT UINTN  *ReceivedLength) {
    EFI_STATUS              Status;
    EFI_TCP4_IO_TOKEN       RxToken;
    EFI_TCP4_RECEIVE_DATA   RxData;
    EFI_TCP4_FRAGMENT_DATA  Fragment;
    BOOLEAN                 RxDone;
    UINT32                  TimeElapsed;
    UINT8                   *Buffer;
    // Buffer de 4 KB.
    UINTN                   BufferSize = 4096;

    Print(L"\n===== Recibiendo datos TCP =====\n");
    Print(L"    - Timeout: %d ms\n", TimeoutMs);

        // Asignar buffer para recepción
        Buffer = AllocateZeroPool(BufferSize);
        if (Buffer == NULL) {
            Print(L"[ERROR]: No se pudo asignar buffer\n");
            return EFI_OUT_OF_RESOURCES;
        }

    ZeroMem(&RxToken, sizeof(RxToken));
    ZeroMem(&RxData, sizeof(RxData));
    ZeroMem(&Fragment, sizeof(Fragment));
    RxDone = FALSE;

    // Crear evento de recepción
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              ReceiveCallback,
                              &RxDone,
                              &RxToken.CompletionToken.Event);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear evento RX :( => %r\n", Status);
        FreePool(Buffer);
        return Status;
    }

    // Configurar datos de recepción
    Fragment.FragmentLength = (UINT32)BufferSize;
    Fragment.FragmentBuffer = Buffer;

    RxData.UrgentFlag = FALSE;
    RxData.DataLength = (UINT32)BufferSize;
    RxData.FragmentCount = 1;
    RxData.FragmentTable[0] = Fragment;

    RxToken.Packet.RxData = &RxData;
    RxToken.CompletionToken.Status = EFI_NOT_READY;

    // Iniciar recepción
    Status = mTcp4Protocol->Receive(mTcp4Protocol, &RxToken);
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: Receive() falló: %r\n", Status);
        gBS->CloseEvent(RxToken.CompletionToken.Event);
        FreePool(Buffer);
        return Status;
    }

    // Esperar datos
    TimeElapsed = 0;
    while (!RxDone && TimeElapsed < TimeoutMs) {
        mTcp4Protocol->Poll(mTcp4Protocol);
        gBS->Stall(1000);
        TimeElapsed += 1;

        // Mostrar progreso cada segundo
        if (TimeElapsed % 1000 == 0) {
            Print(L"    ... [%d] segundos\n", TimeElapsed / 1000);
        }
    }

    if (!RxDone) {
        Print(L"[ERROR]: Timeout recibiendo datos :(\n");
        mTcp4Protocol->Cancel(mTcp4Protocol, &RxToken.CompletionToken);
        gBS->CloseEvent(RxToken.CompletionToken.Event);
        FreePool(Buffer);
        return EFI_TIMEOUT;
    }

    // Verificar resultado
    if (EFI_ERROR(RxToken.CompletionToken.Status)) {
        Print(L"[ERROR]: error en Receive: %r\n", RxToken.CompletionToken.Status);
        Status = RxToken.CompletionToken.Status;
        gBS->CloseEvent(RxToken.CompletionToken.Event);
        FreePool(Buffer);
        return Status;
    }

    // Copiar datos recibidos
    *ReceivedLength = RxData.FragmentTable[0].FragmentLength;
    *ReceivedData = AllocateZeroPool(*ReceivedLength);
    if (*ReceivedData == NULL) {
        Print(L"[ERROR]: No se pudo asignar memoria para 'ReceivedData' :(\n");
        gBS->CloseEvent(RxToken.CompletionToken.Event);
        FreePool(Buffer);
        return EFI_OUT_OF_RESOURCES;
    }
    CopyMem(*ReceivedData, Buffer, *ReceivedLength);

    Print(L"[OK] Datos recibidos en [%d] ms\n", TimeElapsed);

    gBS->CloseEvent(RxToken.CompletionToken.Event);
    FreePool(Buffer);
    return EFI_SUCCESS;
}


EFI_STATUS CloseTcpConnection(VOID) {
    EFI_STATUS              Status;
    EFI_TCP4_CLOSE_TOKEN    CloseToken;
    BOOLEAN                 CloseDone;
    UINT32                  TimeElapsed;
    UINT32                  TimeoutMs = 5000;

    Print(L"\n===== Cerrando TCP4 connection =====\n");

    ZeroMem(&CloseToken, sizeof(CloseToken));
    CloseDone = FALSE;

    // Crear evento de cierre
    Status = gBS->CreateEvent(
                    EVT_NOTIFY_SIGNAL,
                    TPL_CALLBACK,
                    CloseCallback,
                    &CloseDone,
                    &CloseToken.CompletionToken.Event
                    );
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear evento de cierre: %r\n", Status);
        return Status;
    }

    CloseToken.AbortOnClose = FALSE;  // Cierre graceful

    // Iniciar cierre
    Status = mTcp4Protocol->Close(mTcp4Protocol, &CloseToken);
    if (EFI_ERROR(Status)) {
        Print(L"[ERROR]: Close() falló: %r\n", Status);
        gBS->CloseEvent(CloseToken.CompletionToken.Event);
        return Status;
    }

    // Esperar cierre
    TimeElapsed = 0;
    while (!CloseDone && TimeElapsed < TimeoutMs) {
        mTcp4Protocol->Poll(mTcp4Protocol);
        gBS->Stall(1000);
        TimeElapsed += 1;
    }

    if (!CloseDone) {
        Print(L"[ERROR]: Timeout cerrando.\n");
        mTcp4Protocol->Cancel(mTcp4Protocol, &CloseToken.CompletionToken);
        gBS->CloseEvent(CloseToken.CompletionToken.Event);
        return EFI_TIMEOUT;
    }

    // Verificar resultado
    if (EFI_ERROR(CloseToken.CompletionToken.Status)) {
        Print(L"[ERROR]: error en Close :( => %r\n", CloseToken.CompletionToken.Status);
        Status = CloseToken.CompletionToken.Status;
    } else {
        Print(L"[OK] Close: cerrada en [%d] ms.\n", TimeElapsed);
        Status = EFI_SUCCESS;
    }

    gBS->CloseEvent(CloseToken.CompletionToken.Event);
    return Status;
}
