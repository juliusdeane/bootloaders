#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>

#include <Library/BaseMemoryLib.h>
#include <Library/MemoryAllocationLib.h>

#include <Protocol/Ip4.h>
#include <Protocol/Ip4Config2.h>

#include <Protocol/ServiceBinding.h>
#include <Protocol/ShellParameters.h>

// Para generar aleatorios:
#include <Protocol/Rng.h>


// Variables globales
EFI_IP4_PROTOCOL                *mIp4Protocol = NULL;
EFI_HANDLE                      mIp4ChildHandle = NULL;
EFI_SERVICE_BINDING_PROTOCOL    *mServiceBinding = NULL;


// Nuestra propia clase IP_ADDRESS:
typedef struct {
    UINT8 Octet[4];
} IP_ADDRESS;


#pragma pack(1)
typedef struct {
    UINT8   Type;          // 8 = Echo Request, 0 = Echo Reply
    UINT8   Code;          // 0 para Echo
    UINT16  Checksum;      // Checksum del paquete ICMP
    UINT16  Identifier;    // Identificador
    UINT16  SequenceNumber; // Número de secuencia
    UINT8   Data[56];      // Payload (56 bytes es estándar)
} ICMP_ECHO_PACKET;
#pragma pack()

STATIC UINTN StringToINTN(IN CHAR16 *String);
EFI_STATUS ParseIpAddress (IN  CHAR16      *IpString,
                           OUT IP_ADDRESS  *IpAddress);
UINT16 CalculateChecksum (IN UINT16  *Buffer,
                          IN UINTN   Size);

VOID EFIAPI TxCallback (IN EFI_EVENT  Event,
                        IN VOID       *Context);
VOID EFIAPI RxCallback (IN EFI_EVENT  Event,
                        IN VOID       *Context);

EFI_STATUS InitializeIp4Protocol (VOID);

VOID CleanupIp4Protocol (VOID);

EFI_STATUS SendIcmpEchoRequest (IN EFI_IPv4_ADDRESS  *DestAddress,
                                IN UINT16            Identifier,
                                IN UINT16            SequenceNumber);

EFI_STATUS ReceiveIcmpEchoReply (IN UINT32  TimeoutMs);

EFI_STATUS DoPingSequence (IN EFI_IPv4_ADDRESS  *DestAddress,
                           IN UINT32            Count);


EFI_STATUS EFIAPI UefiMain(IN EFI_HANDLE        ImageHandle,
                           IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS                      Status;
    EFI_IP4_CONFIG2_PROTOCOL        *Ip4Config2;
    EFI_IP4_CONFIG2_INTERFACE_INFO  *IfInfo;
    UINTN                           DataSize;
    EFI_SHELL_PARAMETERS_PROTOCOL   *ShellArguments;
    UINTN                           Argc = 0;
    IP_ADDRESS                      argumentIP;
    EFI_IPv4_ADDRESS                DestAddress;

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

    if (Argc == 2) {
        Status = ParseIpAddress(ShellArguments->Argv[1], &argumentIP);
        if (EFI_ERROR(Status)) {
            Print(L"[ERROR] [UefiMain]: no se han podido parsear la IP [%s] :( => %r.\n", ShellArguments->Argv[1],
                                                                                          Status);
            return Status;
        }
    }
    else {
        Print(L"[ERROR]: es necesario el parámetro de la IP destino.\n");
        return EFI_INVALID_PARAMETER;
    }

    // He optado por tener DOS instancia, una con nuestra struct IP_ADDRESS (argumentIP)
    // y la otra con la de edk2: EFI_IPv4_ADDRESS (DestAddress).
    DestAddress.Addr[0] = argumentIP.Octet[0];
    DestAddress.Addr[1] = argumentIP.Octet[1];
    DestAddress.Addr[2] = argumentIP.Octet[2];
    DestAddress.Addr[3] = argumentIP.Octet[3];

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

    // Obtenemos el tamaño de los datos con GetData:
    DataSize = 0;
    Status = Ip4Config2->GetData(Ip4Config2,
                                 Ip4Config2DataTypeInterfaceInfo,
                                 &DataSize,
                                 NULL);

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

    // Dirección IP: al estilo Ip4Config2.
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

    //************************************************************************
    // PING: empieza aquí...
    //************************************************************************
    Status = InitializeIp4Protocol();
    if (EFI_ERROR (Status)) {
        Print(L"[ERROR]: no se pudo inicializar IP4 Protocol :( => %r\n", Status);
        return Status;
    }

    Status = DoPingSequence(&DestAddress, 4);
    CleanupIp4Protocol();
    //************************************************************************
    // END PING.
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

            // Reiniciar buffer
            BufferIndex = 0;
            ZeroMem(TempBuffer, sizeof(TempBuffer));
        } else {
            return EFI_INVALID_PARAMETER; // Carácter inválido
        }

        Ptr++;
    }

    // Procesar el último octeto
    if (BufferIndex > 0 && OctetIndex == 3) {
        TempBuffer[BufferIndex] = L'\0';
        Value = StringToINTN(TempBuffer);

        if (Value > 255) {
            return EFI_INVALID_PARAMETER;
        }

        IpAddress->Octet[OctetIndex++] = (UINT8)Value;
    }

    // Verificar que tenemos exactamente 4 octetos
    if (OctetIndex != 4) {
        return EFI_INVALID_PARAMETER;
    }

    return EFI_SUCCESS;
}


UINT16 CalculateChecksum(IN UINT16  *Buffer,
                         IN UINTN   Size) {
    UINT32  Sum = 0;
    UINT16  *Ptr = Buffer;
    UINTN   Count = Size / 2;

    // Sumar palabras de 16 bits
    while (Count > 0) {
        Sum += *Ptr++;
        Count--;
    }

    // Si hay un byte impar, agregarlo
    if (Size & 1) {
        Sum += *(UINT8 *)Ptr;
    }

    // Plegar los bits superiores en los inferiores
    while (Sum >> 16) {
        Sum = (Sum & 0xFFFF) + (Sum >> 16);
    }

    return (UINT16)~Sum;
}


VOID EFIAPI TxCallback(IN EFI_EVENT  Event,
                       IN VOID       *Context) {
    BOOLEAN *TxDone = (BOOLEAN *)Context;
    *TxDone = TRUE;
}


VOID EFIAPI RxCallback(IN EFI_EVENT  Event,
                       IN VOID       *Context) {
    BOOLEAN *RxDone = (BOOLEAN *)Context;
    *RxDone = TRUE;
}


EFI_STATUS InitializeIp4Protocol(VOID) {
    EFI_STATUS           Status;
    UINTN                HandleCount;
    EFI_HANDLE           *HandleBuffer;
    EFI_IP4_CONFIG_DATA  Ip4ConfigData;

    // Buscar handles con IP4 Service Binding Protocol
    Status = gBS->LocateHandleBuffer (ByProtocol,
                                      &gEfiIp4ServiceBindingProtocolGuid,
                                      NULL,
                                      &HandleCount,
                                      &HandleBuffer);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se encontraron interfaces de red IP4 :( => %r\n", Status);
        return Status;
    }

    Print(L"[OK]: encontradas %d interfaces de red.\n", HandleCount);

    // Usar la primera interfaz disponible:
    // - en cuanto la encontramos la configuramos y devolvemos EFI_SUCCESS.
    // - esto sale del bucle for de facto.
    for (UINTN Index = 0; Index < HandleCount; Index++) {
        Status = gBS->HandleProtocol(HandleBuffer[Index],
                                     &gEfiIp4ServiceBindingProtocolGuid,
                                     (VOID **)&mServiceBinding);

        if(EFI_ERROR(Status)) {
            // Pasamos a la siguiente:
            continue;
        }

        // Crear un hijo (instancia de IP4)
        mIp4ChildHandle = NULL;
        Status = mServiceBinding->CreateChild(mServiceBinding, &mIp4ChildHandle);
        if(EFI_ERROR(Status)) {
            Print(L"[ERROR]: no se pudo crear 'hijo IP4' :( => %r\n", Status);
            continue;
        }

        // Obtener el protocolo IP4
        Status = gBS->HandleProtocol(mIp4ChildHandle,
                                     &gEfiIp4ProtocolGuid,
                                     (VOID **)&mIp4Protocol);

        if(EFI_ERROR(Status)) {
            Print(L"ERROR: No se pudo obtener IP4 Protocol: %r\n", Status);
            mServiceBinding->DestroyChild (mServiceBinding, mIp4ChildHandle);
            continue;
        }

        // Configurar el protocolo IP4
        ZeroMem(&Ip4ConfigData, sizeof (Ip4ConfigData));

        Ip4ConfigData.DefaultProtocol = 1;  // ICMP = 1
        Ip4ConfigData.AcceptAnyProtocol = FALSE;
        Ip4ConfigData.AcceptIcmpErrors = TRUE;
        Ip4ConfigData.AcceptBroadcast = FALSE;
        Ip4ConfigData.AcceptPromiscuous = FALSE;
        Ip4ConfigData.UseDefaultAddress = TRUE;
        Ip4ConfigData.StationAddress.Addr[0] = 0;
        Ip4ConfigData.SubnetMask.Addr[0] = 0;
        Ip4ConfigData.TypeOfService = 0;
        Ip4ConfigData.TimeToLive = 64;
        Ip4ConfigData.DoNotFragment = FALSE;
        Ip4ConfigData.RawData = FALSE;
        Ip4ConfigData.ReceiveTimeout = 0;
        Ip4ConfigData.TransmitTimeout = 0;

        Status = mIp4Protocol->Configure(mIp4Protocol, &Ip4ConfigData);
        if(EFI_ERROR (Status)) {
            Print(L"[ERROR]: no se pudo configurar IP4 :( => %r\n", Status);
            mServiceBinding->DestroyChild(mServiceBinding, mIp4ChildHandle);
            continue;
        }

        Print(L"[OK]: Protocolo IP4 inicializado correctamente!\n");
        FreePool (HandleBuffer);
        return EFI_SUCCESS;
    }

    // Si hemos llegado hasta aquí, no hemos encontrado una tarjeta de red.
    FreePool (HandleBuffer);
    return EFI_NOT_FOUND;
}


VOID CleanupIp4Protocol (VOID) {
    if (mIp4Protocol != NULL) {
        mIp4Protocol->Configure (mIp4Protocol, NULL);
    }

    if (mServiceBinding != NULL && mIp4ChildHandle != NULL) {
        mServiceBinding->DestroyChild (mServiceBinding, mIp4ChildHandle);
    }
}


EFI_STATUS SendIcmpEchoRequest(IN EFI_IPv4_ADDRESS  *DestAddress,
                               IN UINT16            Identifier,
                               IN UINT16            SequenceNumber) {
    EFI_STATUS                Status;
    ICMP_ECHO_PACKET          *IcmpPacket;
    EFI_IP4_COMPLETION_TOKEN  TxToken;
    EFI_IP4_TRANSMIT_DATA     TxData;
    EFI_IP4_FRAGMENT_DATA     Fragment;
    BOOLEAN                   TxDone;
    UINTN                     Index;

    Print(L"\n===== Enviando ICMP Echo Request =====\n");
    Print(L"Destino: %d.%d.%d.%d\n", DestAddress->Addr[0],
                                      DestAddress->Addr[1],
                                      DestAddress->Addr[2],
                                      DestAddress->Addr[3]);
    Print(L"ID: 0x%04x, Seq: %d\n", Identifier, SequenceNumber);

    //************************************************************************
    // BLOQUE 1: el paquete ICMP
    // Asignar memoria para el paquete ICMP
    //************************************************************************
    IcmpPacket = AllocateZeroPool(sizeof(ICMP_ECHO_PACKET));
    if(IcmpPacket == NULL) {
        Print(L"ERROR: No se pudo asignar memoria para el paquete\n");
        return EFI_OUT_OF_RESOURCES;
    }

    // Construir paquete ICMP Echo Request
    IcmpPacket->Type = 8;  // Echo Request
    IcmpPacket->Code = 0;
    IcmpPacket->Checksum = 0;
    IcmpPacket->Identifier = Identifier;
    IcmpPacket->SequenceNumber = SequenceNumber;

    // Llenar datos un patrón generado por nosotros:
    // - empieza en 'A' (0x41)
    // - si llega a 'Z' (0x5A) reinicia a 'A'.
    UINTN  characterDisplacement = 0;
    for(Index = 0; Index < sizeof(IcmpPacket->Data); Index++) {
        UINT8 character = (UINT8)(0x41 + characterDisplacement);
        IcmpPacket->Data[Index] = character;
        if (character == 0x5A) {  // Si es 'Z', volvemos al inicio de displacement.
            characterDisplacement = 0;
        }
        else {
            // Incrementamos el desplazamiento de posición desde 0x41 + displacement:
            characterDisplacement++;
        }
    }

    // Calcular checksum
    IcmpPacket->Checksum = CalculateChecksum((UINT16 *)IcmpPacket,
                                             sizeof(ICMP_ECHO_PACKET));

    Print(L"Checksum calculado: 0x%04x\n", IcmpPacket->Checksum);

    //************************************************************************
    // BLOQUE 2: el token de transmisión
    // Configurar token de transmisión
    //************************************************************************
    ZeroMem(&TxToken, sizeof(TxToken));
    ZeroMem(&TxData, sizeof(TxData));
    ZeroMem(&Fragment, sizeof(Fragment));

    TxDone = FALSE;

    // Crear evento para notificación
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,  // Tipo de evento a atender
                              TPL_CALLBACK,       // Nivel de prioridad (TPL)
                              TxCallback,         // El callback que invocaremos
                              &TxDone,            // El flag de Done
                              &TxToken.Event);    // El evento guardado en el token

    if(EFI_ERROR (Status)) {
        Print(L"[ERROR]: no se pudo crear evento TX (icmp-request) :( => %r\n", Status);
        FreePool (IcmpPacket);
        return Status;
    }

    //************************************************************************
    // Configurar datos de transmisión y envío del paquete REQUEST
    //************************************************************************
    CopyMem(&TxData.DestinationAddress, DestAddress, sizeof(EFI_IPv4_ADDRESS));
    TxData.OverrideData = NULL;
    TxData.OptionsLength = 0;
    TxData.OptionsBuffer = NULL;
    TxData.TotalDataLength = sizeof(ICMP_ECHO_PACKET);
    TxData.FragmentCount = 1;

    Fragment.FragmentLength = sizeof(ICMP_ECHO_PACKET);
    Fragment.FragmentBuffer = IcmpPacket;
    TxData.FragmentTable[0] = Fragment;

    TxToken.Packet.TxData = &TxData;

    // Transmitir paquete ICMP-REQUEST:
    Status = mIp4Protocol->Transmit(mIp4Protocol, &TxToken);
    if(EFI_ERROR (Status)) {
        Print(L"[ERROR]: transmit no ha funcionado :( => %r\n", Status);
        gBS->CloseEvent(TxToken.Event);
        FreePool (IcmpPacket);
        return Status;
    }

    Print(L"[!!!] Esperando que se complete transmit...\n");
    // Esperar hasta que la transmisión se complete
    while(!TxDone) {
        mIp4Protocol->Poll(mIp4Protocol);
    }

    // Verificar estado
    if(EFI_ERROR (TxToken.Status)) {
        Print (L"[ERROR]: Transmisión completada con error: %r\n", TxToken.Status);
        Status = TxToken.Status;
    } else {
        Status = EFI_SUCCESS;
    }

    // Limpiar
    gBS->CloseEvent(TxToken.Event);
    FreePool(IcmpPacket);

    return Status;
}


EFI_STATUS ReceiveIcmpEchoReply(IN UINT32  TimeoutMs) {
    EFI_STATUS                Status;
    EFI_IP4_COMPLETION_TOKEN  RxToken;
    EFI_IP4_RECEIVE_DATA      *RxData;
    BOOLEAN                   RxDone;
    ICMP_ECHO_PACKET          *IcmpReply;
    UINT32                    TimeElapsed;
    UINT32                    PollInterval = 10;  // ms

    Print (L"\n===== Esperando ICMP echo-reply =====\n");
    Print (L"    - Timeout: [%d] ms\n", TimeoutMs);

    ZeroMem(&RxToken, sizeof (RxToken));
    RxDone = FALSE;

    // Crear evento para recepción
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              RxCallback,
                              &RxDone,
                              &RxToken.Event);

    if (EFI_ERROR (Status)) {
        Print (L"[ERROR]: no se pudo crear evento RX :( => %r\n", Status);
        return Status;
    }

    // Iniciar recepción
    Status = mIp4Protocol->Receive(mIp4Protocol, &RxToken);
    if (EFI_ERROR (Status)) {
        Print (L"[ERROR]: receive no pudo completarse :( => %r\n", Status);
        gBS->CloseEvent (RxToken.Event);
        return Status;
    }

    // Esperar respuesta con timeout
    TimeElapsed = 0;
    while (!RxDone && TimeElapsed < TimeoutMs) {
        mIp4Protocol->Poll (mIp4Protocol);
        gBS->Stall (PollInterval * 1000);  // Convertir ms a microsegundos
        TimeElapsed += PollInterval;
    }

    if(!RxDone) {
        Print (L"✗ TIMEOUT: No se recibió respuesta en [%d] ms...\n", TimeoutMs);
        mIp4Protocol->Cancel (mIp4Protocol, &RxToken);
        gBS->CloseEvent (RxToken.Event);
        return EFI_TIMEOUT;
    }

    // Verificar estado de recepción
    if (EFI_ERROR(RxToken.Status)) {
        Print (L"[ERROR]: error al recibir los datos 'RxToken.Status' :( => %r\n", RxToken.Status);
        gBS->CloseEvent (RxToken.Event);
        return RxToken.Status;
    }

    // Procesar paquete recibido
    RxData = RxToken.Packet.RxData;
    if (RxData == NULL || RxData->FragmentCount == 0) {
        Print (L"[ERROR]: datos recibidos incorrectos ('RxData == NULL' o 'RxData->FragmentCount == 0')!\n");
        gBS->CloseEvent (RxToken.Event);
        return EFI_PROTOCOL_ERROR;
    }

    // Esta es la estructura con la respuesta ICMP:
    IcmpReply = (ICMP_ECHO_PACKET *)RxData->FragmentTable[0].FragmentBuffer;

    // Primero el número de secuencia, luego el identificador.
    // *OJO que no hay retorno de carro, quiero imprimir en la misma línea.
    Print (L"SEQ: (%d) ID: [0x%04x] Time: (%d ms)| ", IcmpReply->SequenceNumber,
                                                      IcmpReply->Identifier,
                                                      TimeElapsed);

    Print (L"%d.%d.%d.%d | ", RxData->Header->SourceAddress.Addr[0],
                              RxData->Header->SourceAddress.Addr[1],
                              RxData->Header->SourceAddress.Addr[2],
                              RxData->Header->SourceAddress.Addr[3]);

    Print (L"[%d] bytes | ", RxData->DataLength);

    // Extraer paquete ICMP
    IcmpReply = (ICMP_ECHO_PACKET *)RxData->FragmentTable[0].FragmentBuffer;
    Print (L"ICMP Type: %d/Code: %d\n", IcmpReply->Type, IcmpReply->Code);


    if (IcmpReply->Type == 0) {
        Print (L"(✓ ICMP Echo Reply recibido correctamente)\n");
    } else if (IcmpReply->Type == 8) {
        Print (L"(⚠ ICMP Echo Request - eco de nuestro propio paquete?)\n");
    } else {
        Print (L"(⚠ ICMP Type inesperado: %d)\n", IcmpReply->Type);
    }

    // Señalar que hemos terminado con los datos
    if (RxData->RecycleSignal != NULL) {
        gBS->SignalEvent (RxData->RecycleSignal);
    }

    gBS->CloseEvent (RxToken.Event);
    return EFI_SUCCESS;
}


EFI_STATUS DoPingSequence(IN EFI_IPv4_ADDRESS  *DestAddress,
                          IN UINT32            Count) {
    EFI_STATUS  Status;
    UINT16      Identifier = 0xbeef;  // dead-beef :)
    UINT16      Sequence;

    Print(L"[OK]: UINT16 Identifier=[0x%04x].\n", Identifier);

    for(Sequence = 1; Sequence <= Count; Sequence++) {
        Print(L"\n--- Ping #%d ---\n", Sequence);

        // Enviar Echo Request
        Status = SendIcmpEchoRequest (DestAddress, Identifier, Sequence);
        if(EFI_ERROR (Status)) {
            Print(L"[ERROR]: enviando icmp-red [#%d] => %r\n", Sequence,
                                                               Status);
            continue;
        }

        // Recibir Echo Reply
        Status = ReceiveIcmpEchoReply(5000);  // 5 segundos timeout
        if(EFI_ERROR (Status)) {
            Print(L"[ERROR]: recibiendo res para icmp-req [#%d] => %r\n", Sequence,
                                                                          Status);
        }

        // Pausa entre pings
        if(Sequence < Count) {
            // Esperamos 1 seg.
            gBS->Stall(1000000);  // 1 segundo
        }
    }

    return EFI_SUCCESS;
}
