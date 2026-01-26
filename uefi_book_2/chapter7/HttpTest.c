#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PrintLib.h>

#include <Protocol/Http.h>
#include <Protocol/ServiceBinding.h>
#include <Protocol/Ip4Config2.h>
#include <Protocol/ShellParameters.h>


#define DEFAULT_SERVER_PORT  80


// Variables globales
EFI_HTTP_PROTOCOL                  *mHttpProtocol = NULL;
EFI_HANDLE                         mHttpChildHandle = NULL;
EFI_SERVICE_BINDING_PROTOCOL       *mServiceBinding = NULL;


// Nuestra propia clase IP_ADDRESS:
typedef struct {
    UINT8 Octet[4];
} IP_ADDRESS;


STATIC UINTN StringToINTN(IN CHAR16 *String);
EFI_STATUS ParseIpAddress(IN  CHAR16      *IpString,
                          OUT IP_ADDRESS  *IpAddress);

// Funciones HTTP
EFI_STATUS InitializeHttpProtocol(VOID);
VOID CleanupHttpProtocol(VOID);
EFI_STATUS ConfigureHttp(IN CHAR16  *HostName,
                         IN UINT16  Port);
EFI_STATUS SendHttpRequest(IN CHAR16  *Url,
                           IN CHAR16  *HostName);
EFI_STATUS ReceiveHttpResponse(OUT UINT8  **ResponseData,
                               OUT UINTN  *ResponseLength);

// Callbacks
VOID EFIAPI HttpRequestCallback(IN EFI_EVENT  Event,
                                IN VOID       *Context);
VOID EFIAPI HttpResponseCallback(IN EFI_EVENT  Event,
                                 IN VOID       *Context);


EFI_STATUS EFIAPI UefiMain(IN EFI_HANDLE        ImageHandle,
                           IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS                      Status;
    EFI_IP4_CONFIG2_PROTOCOL        *Ip4Config2;
    EFI_IP4_CONFIG2_INTERFACE_INFO  *IfInfo;
    UINTN                           DataSize;
    EFI_SHELL_PARAMETERS_PROTOCOL   *ShellArguments;
    UINTN                           Argc = 0;
    CHAR16                          *HostName;
    CHAR16                          *Path;
    UINT16                          Port;
    UINT8                           *ResponseData;
    UINTN                           ResponseLength;

    // Obtener el protocolo de parámetros del shell
    Status = gBS->OpenProtocol(ImageHandle,
                               &gEfiShellParametersProtocolGuid,
                               (VOID **)&ShellArguments,
                               ImageHandle,
                               NULL,
                               EFI_OPEN_PROTOCOL_GET_PROTOCOL);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: no se han podido obtener los argumentos :( => %r.\n", Status);
        return Status;
    }

    // Mostrar los argumentos
    Argc = ShellArguments->Argc;
    Print(L"[OK] Total de argumentos (Argc): %d\n", Argc);
    for(UINTN Index = 0; Index < Argc; Index++) {
        Print(L"    - Argv[%d]: %s\n", Index, ShellArguments->Argv[Index]);
    }

    // Necesitamos URL y opcionalmente puerto: HttpTest.efi <hostname> <path> [puerto]
    // Ejemplo: HttpTest.efi example.com /index.html 80
    if(Argc >= 3) {
        HostName = ShellArguments->Argv[1];
        Path = ShellArguments->Argv[2];

        // Puerto opcional, por defecto 80
        if(Argc >= 4) {
            Port = (UINT16)StringToINTN(ShellArguments->Argv[3]);
            if (Port == 0) {
                Print(L"[ERROR] [UefiMain]: puerto incorrecto [%s].\n", ShellArguments->Argv[3]);
                return EFI_INVALID_PARAMETER;
            }
        } else {
            // Puerto HTTP por defecto: por hacerlo fácil, el 80/tcp.
            Port = DEFAULT_SERVER_PORT;
        }
    } else {
        Print(L"[ERROR]: uso: HttpTest.efi <hostname> <path> [puerto]\n");
        Print(L"    Ejemplo: HttpTest.efi example.com /index.html\n");
        Print(L"    Ejemplo: HttpTest.efi 192.168.1.10 /api/test 8080\n");
        return EFI_INVALID_PARAMETER;
    }

    Print(L"[OK] Conectando a HTTP: %s:%d%s\n", HostName, Port, Path);

    // Localizamos el protocolo IP4_CONFIG2 (para mostrar info de interfaz)
    Status = gBS->LocateProtocol(&gEfiIp4Config2ProtocolGuid,
                                 NULL,
                                 (VOID **)&Ip4Config2);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR] [UefiMain]: No se pudo localizar IP4_CONFIG2_PROTOCOL :( => %r.\n", Status);
        return Status;
    }

    // Obtenemos el tamaño de los datos con GetData:
    DataSize = 0;
    Status = Ip4Config2->GetData(Ip4Config2,
                                 Ip4Config2DataTypeInterfaceInfo,
                                 &DataSize,
                                 NULL);

    if(Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"[ERROR] [UefiMain]: no puedo obtener 'DataSize'.\n");
        return Status;
    }

    // Asignamos memoria
    IfInfo = AllocatePool(DataSize);
    if(IfInfo == NULL) {
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
    // HTTP: empieza aquí...
    //************************************************************************
    Status = InitializeHttpProtocol();
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo inicializar HTTP Protocol :( => %r\n", Status);
        FreePool(IfInfo);
        return Status;
    }

    // Configurar HTTP
    Status = ConfigureHttp(HostName, Port);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo configurar HTTP :( => %r\n", Status);
        CleanupHttpProtocol();
        FreePool(IfInfo);
        return Status;
    }

    Print(L"[OK] HTTP configurado correctamente!\n\n");

    // Construir URL completa
    UINTN UrlLen = StrLen(L"http://") + StrLen(HostName) + 10 + StrLen(Path) + 1;
    CHAR16 *Url = AllocateZeroPool(UrlLen * sizeof(CHAR16));
    if(Url == NULL) {
        Print(L"[ERROR]: No se pudo asignar memoria para la URL :(\n");
        CleanupHttpProtocol();
        FreePool(IfInfo);
        return EFI_OUT_OF_RESOURCES;
    }

    if(Port == DEFAULT_SERVER_PORT) {
        UnicodeSPrint(Url, UrlLen * sizeof(CHAR16), L"http://%s%s", HostName, Path);
    } else {
        UnicodeSPrint(Url, UrlLen * sizeof(CHAR16), L"http://%s:%d%s", HostName, Port, Path);
    }

    // Enviar petición HTTP GET
    Print(L"[!!!] Enviando request HTTP GET a: %s\n", Url);
    Status = SendHttpRequest(Url, HostName);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo enviar la request HTTP :( => %r\n", Status);
        FreePool(Url);
        CleanupHttpProtocol();
        FreePool(IfInfo);
        return Status;
    }

    // Recibir respuesta HTTP
    Print(L"[!!!] Esperando respuesta del servidor HTTP...\n");
    Status = ReceiveHttpResponse(&ResponseData, &ResponseLength);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: no se pudo recibir la respuesta HTTP :( => %r\n", Status);
        FreePool(Url);
        CleanupHttpProtocol();
        FreePool(IfInfo);
        return Status;
    }

    Print(L"[OK] Respuesta HTTP recibida: %d bytes\n", ResponseLength);

    // Mostramos los primeros caracteres (limitado a 512)
    UINTN PrintLen = (ResponseLength > 512) ? 512 : ResponseLength;
    Print(L"\n----- Inicio de respuesta HTTP -----\n");
    for(UINTN i = 0; i < PrintLen; i++) {
        Print(L"%c", (CHAR16)ResponseData[i]);
    }

    if(ResponseLength > 512) {
        Print(L"\n... (truncado) ...");
    }
    Print(L"\n----- Fin de respuesta HTTP -----\n\n");

    // Liberar recursos
    if(ResponseData != NULL) {
        FreePool(ResponseData);
    }
    FreePool(Url);
    CleanupHttpProtocol();
    FreePool(IfInfo);

    Print(L"[OK] Todo correcto!\n");
    return EFI_SUCCESS;
}


STATIC UINTN StringToINTN(IN CHAR16 *String) {
    UINTN   Result = 0;
    CHAR16  *Ptr = String;

    if (String == NULL) {
        return 0;
    }

    while (*Ptr != L'\0') {
        if (*Ptr >= L'0' && *Ptr <= L'9') {
            Result = Result * 10 + (*Ptr - L'0');
        } else {
            return 0;  // Carácter inválido
        }
        Ptr++;
    }

    return Result;
}


EFI_STATUS ParseIpAddress(IN  CHAR16      *IpString,
                          OUT IP_ADDRESS  *IpAddress) {
    CHAR16  *Token;
    CHAR16  *NextToken;
    UINTN   Index;
    CHAR16  TempBuffer[256];

    if (IpString == NULL || IpAddress == NULL) {
        return EFI_INVALID_PARAMETER;
    }

    // Copiar a buffer temporal
    StrCpyS(TempBuffer, 256, IpString);

    Token = TempBuffer;
    for (Index = 0; Index < 4; Index++) {
        NextToken = StrStr(Token, L".");

        if (Index < 3) {
            if (NextToken == NULL) {
                return EFI_INVALID_PARAMETER;
            }
            *NextToken = L'\0';
        }

        IpAddress->Octet[Index] = (UINT8)StringToINTN(Token);

        if (NextToken != NULL) {
            Token = NextToken + 1;
        }
    }

    return EFI_SUCCESS;
}


EFI_STATUS InitializeHttpProtocol(VOID) {
    EFI_STATUS  Status;
    UINTN       HandleCount;
    EFI_HANDLE  *HandleBuffer;

    Print(L"\n===== Inicializando HTTP Protocol =====\n");

    // Buscar todos los handles con HTTP Service Binding
    Status = gBS->LocateHandleBuffer(ByProtocol,
                                     &gEfiHttpServiceBindingProtocolGuid,
                                     NULL,
                                     &HandleCount,
                                     &HandleBuffer);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se ha encontrado HTTP Service Binding :( => %r\n", Status);
        return Status;
    }

    Print(L"[OK] Encontrados [%d] handles con HTTP Service Binding:\n", HandleCount);

    // Intentar con el primer handle
    Status = gBS->OpenProtocol(HandleBuffer[0],
                               &gEfiHttpServiceBindingProtocolGuid,
                               (VOID **)&mServiceBinding,
                               gImageHandle,
                               NULL,
                               EFI_OPEN_PROTOCOL_GET_PROTOCOL);
    FreePool(HandleBuffer);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo abrir HTTP Service Binding: %r\n", Status);
        return Status;
    }

    // Crear child handle para HTTP:
    mHttpChildHandle = NULL;
    Status = mServiceBinding->CreateChild(mServiceBinding, &mHttpChildHandle);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear 'HTTP child handle' :( => %r\n", Status);
        mServiceBinding = NULL;
        return Status;
    }

    Print(L"[OK] HTTP child handle creado!\n");

    // Abrir el protocolo HTTP
    Status = gBS->OpenProtocol(mHttpChildHandle,
                               &gEfiHttpProtocolGuid,
                               (VOID **)&mHttpProtocol,
                               gImageHandle,
                               NULL,
                               EFI_OPEN_PROTOCOL_GET_PROTOCOL);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo abrir HTTP Protocol: %r\n", Status);
        mServiceBinding->DestroyChild(mServiceBinding, mHttpChildHandle);
        mHttpChildHandle = NULL;
        mServiceBinding = NULL;
        return Status;
    }

    Print(L"[OK] HTTP Protocol inicializado correctamente\n");
    return EFI_SUCCESS;
}


VOID CleanupHttpProtocol(VOID) {
    Print(L"\n===== Limpiando HTTP Protocol =====\n");

    if(mHttpProtocol != NULL) {
        gBS->CloseProtocol(mHttpChildHandle,
                           &gEfiHttpProtocolGuid,
                           gImageHandle,
                           NULL);
        mHttpProtocol = NULL;
    }

    if(mServiceBinding != NULL && mHttpChildHandle != NULL) {
        mServiceBinding->DestroyChild(mServiceBinding, mHttpChildHandle);
        mHttpChildHandle = NULL;
    }

    mServiceBinding = NULL;
    Print(L"[OK] HTTP Protocol limpiado correctamente!\n");
}


EFI_STATUS ConfigureHttp(IN CHAR16  *HostName,
                         IN UINT16  Port) {
    EFI_STATUS               Status;
    EFI_HTTPv4_ACCESS_POINT  IPv4Node;
    EFI_HTTP_CONFIG_DATA     HttpConfigData;

    Print(L"\n===== Configurando HTTP =====\n");
    Print(L"    - Host: %s\n", HostName);
    Print(L"    - Port: %d\n", Port);

    ZeroMem(&HttpConfigData, sizeof(HttpConfigData));
    ZeroMem(&IPv4Node, sizeof(IPv4Node));

    // Configurar para IPv4
    HttpConfigData.HttpVersion = HttpVersion11;
    HttpConfigData.TimeOutMillisec = 10000;  // 10 segundos timeout
    HttpConfigData.LocalAddressIsIPv6 = FALSE;

    // Configuración IPv4
    IPv4Node.UseDefaultAddress = TRUE;  // Usar dirección por defecto (DHCP)
    IPv4Node.LocalPort = 0;  // Puerto local automático

    HttpConfigData.AccessPoint.IPv4Node = &IPv4Node;

    // Aplicar configuración
    Status = mHttpProtocol->Configure(mHttpProtocol, &HttpConfigData);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: Configure() falló: %r\n", Status);
        return Status;
    }

    Print(L"[OK] HTTP configurado correctamente!\n");
    return EFI_SUCCESS;
}


VOID EFIAPI HttpRequestCallback(IN EFI_EVENT  Event,
                                IN VOID       *Context) {
    if (Context != NULL) {
        *(BOOLEAN *)Context = TRUE;
    }
}


EFI_STATUS SendHttpRequest(IN CHAR16  *Url,
                           IN CHAR16  *HostName) {
    EFI_STATUS                  Status;
    EFI_HTTP_TOKEN              RequestToken;
    EFI_HTTP_MESSAGE            RequestMessage;
    EFI_HTTP_REQUEST_DATA       RequestData;
    // Puedes añadir más Headers: recuerda aumentar la lista...
    EFI_HTTP_HEADER             RequestHeaders[3];
    BOOLEAN                     RequestDone;
    UINT32                      TimeElapsed;
    UINT32                      TimeoutMs = 10000;
    CHAR8                       *HostNameAscii;
    UINTN                       HostNameLen;

    Print(L"\n===== Enviando request HTTP =====\n");
    Print(L"    - URL: %s\n", Url);

    // Convertir hostname a ASCII
    HostNameLen = StrLen(HostName) + 1;
    HostNameAscii = AllocateZeroPool(HostNameLen);
    if(HostNameAscii == NULL) {
        Print(L"[ERROR]: No se pudo asignar memoria para 'HostName' :(\n");
        return EFI_OUT_OF_RESOURCES;
    }
    UnicodeStrToAsciiStrS(HostName, HostNameAscii, HostNameLen);

    ZeroMem(&RequestToken, sizeof(RequestToken));
    ZeroMem(&RequestMessage, sizeof(RequestMessage));
    ZeroMem(&RequestData, sizeof(RequestData));
    RequestDone = FALSE;

    // Crear evento para la petición
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              HttpRequestCallback,
                              &RequestDone,
                              &RequestToken.Event);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear evento de petición: %r\n", Status);
        FreePool(HostNameAscii);
        return Status;
    }

    // Configurar headers HTTP
    RequestHeaders[0].FieldName = "Host";
    RequestHeaders[0].FieldValue = HostNameAscii;

    RequestHeaders[1].FieldName = "User-Agent";
    RequestHeaders[1].FieldValue = "MiUEFI-HTTP-Client/1.0";

    RequestHeaders[2].FieldName = "Connection";
    RequestHeaders[2].FieldValue = "close";

    // Configurar datos de la petición
    RequestData.Method = HttpMethodGet;
    RequestData.Url = Url;

    // Configurar mensaje HTTP
    RequestMessage.Data.Request = &RequestData;
    RequestMessage.HeaderCount = 3;
    RequestMessage.Headers = RequestHeaders;
    RequestMessage.BodyLength = 0;
    RequestMessage.Body = NULL;

    RequestToken.Status = EFI_NOT_READY;
    RequestToken.Message = &RequestMessage;

    // Enviar petición
    Status = mHttpProtocol->Request(mHttpProtocol, &RequestToken);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'Request()': %r\n", Status);
        gBS->CloseEvent(RequestToken.Event);
        FreePool(HostNameAscii);
        return Status;
    }

    // Esperar que se complete:
    TimeElapsed = 0;
    while(!RequestDone && TimeElapsed < TimeoutMs) {
        // Poll del protocolo HTTP para procesar la petición
        mHttpProtocol->Poll(mHttpProtocol);

        gBS->Stall(1000);  // 1 ms
        TimeElapsed += 1;
    }

    if(!RequestDone) {
        Print(L"[ERROR]: Timeout enviando request HTTP :(\n");
        mHttpProtocol->Cancel(mHttpProtocol, &RequestToken);
        gBS->CloseEvent(RequestToken.Event);
        FreePool(HostNameAscii);
        return EFI_TIMEOUT;
    }

    // Verificar resultado
    if(EFI_ERROR(RequestToken.Status)) {
        Print(L"[ERROR]: error en request HTTP: %r\n", RequestToken.Status);
        Status = RequestToken.Status;
    } else {
        Print(L"[OK] request HTTP en [%d] ms\n", TimeElapsed);
        Status = EFI_SUCCESS;
    }

    gBS->CloseEvent(RequestToken.Event);
    FreePool(HostNameAscii);
    return Status;
}


VOID EFIAPI HttpResponseCallback(IN EFI_EVENT  Event,
                                 IN VOID       *Context) {
    if(Context != NULL) {
        *(BOOLEAN *)Context = TRUE;
    }
}


EFI_STATUS ReceiveHttpResponse(OUT UINT8  **ResponseData,
                               OUT UINTN  *ResponseLength) {
    EFI_STATUS              Status;
    EFI_HTTP_TOKEN          ResponseToken;
    EFI_HTTP_MESSAGE        ResponseMessage;
    BOOLEAN                 ResponseDone;
    UINT32                  TimeElapsed;
    UINT32                  TimeoutMs = 15000;  // 15 segs.
    UINT8                   *Buffer;
    UINTN                   BufferSize = 8192;
    EFI_HTTP_RESPONSE_DATA  *ResponseData_ptr;

    Print(L"\n===== Recibiendo response HTTP =====\n");
    Print(L"    - Timeout: %d ms\n", TimeoutMs);

    //========================================================================
    // PASO 1: Recibir HEADERS primero
    //========================================================================
    Print(L"[!!!] Paso 1: Recibiendo headers HTTP...\n");

    ZeroMem(&ResponseToken, sizeof(ResponseToken));
    ZeroMem(&ResponseMessage, sizeof(ResponseMessage));
    ResponseDone = FALSE;

    // Crear evento para los headers
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              HttpResponseCallback,
                              &ResponseDone,
                              &ResponseToken.Event);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear evento de response: %r\n", Status);
        return Status;
    }

    // Reservar memoria para la  estructura para la HTTP-response:
    ResponseData_ptr = AllocateZeroPool(sizeof(EFI_HTTP_RESPONSE_DATA));
    if(ResponseData_ptr == NULL) {
        Print(L"[ERROR]: No se pudo reservar memoria para ResponseData :(\n");
        gBS->CloseEvent(ResponseToken.Event);
        return EFI_OUT_OF_RESOURCES;
    }

    // Primero recibimos solo headers (Body = NULL)
    ResponseMessage.Data.Response = ResponseData_ptr;
    ResponseMessage.HeaderCount = 0;
    ResponseMessage.Headers = NULL;
    ResponseMessage.BodyLength = 0;
    ResponseMessage.Body = NULL;  // NULL para recibir solo headers

    ResponseToken.Status = EFI_NOT_READY;
    ResponseToken.Message = &ResponseMessage;

    // Llamar a Response para headers
    Status = mHttpProtocol->Response(mHttpProtocol, &ResponseToken);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'Response()' para *headers*: %r\n", Status);
        gBS->CloseEvent(ResponseToken.Event);
        return Status;
    }

    // Esperar headers con polling activo
    TimeElapsed = 0;
    while(!ResponseDone && TimeElapsed < TimeoutMs) {
        mHttpProtocol->Poll(mHttpProtocol);
        gBS->Stall(1000);
        TimeElapsed += 1;

        if(TimeElapsed % 1000 == 0) {
            Print(L"    ... esperando headers [%d]s\n", TimeElapsed / 1000);
        }
    }

    if(!ResponseDone) {
        Print(L"[ERROR]: Timeout recibiendo headers HTTP\n");
        mHttpProtocol->Cancel(mHttpProtocol, &ResponseToken);
        gBS->CloseEvent(ResponseToken.Event);
        return EFI_TIMEOUT;
    }

    if (EFI_ERROR(ResponseToken.Status)) {
        Print(L"[ERROR]: error recibiendo headers: %r\n", ResponseToken.Status);
        gBS->CloseEvent(ResponseToken.Event);
        return ResponseToken.Status;
    }

    // Mostrar información de headers
    if(ResponseMessage.Data.Response != NULL) {
        Print(L"[OK] Status Code: %d\n", ResponseMessage.Data.Response->StatusCode);
        Print(L"[OK] Headers recibidos: %d\n", ResponseMessage.HeaderCount);

        // Mostrar algunos headers
        for(UINTN i = 0; i < ResponseMessage.HeaderCount && i < 5; i++) {
            Print(L"    %a: %a\n",
                  ResponseMessage.Headers[i].FieldName,
                  ResponseMessage.Headers[i].FieldValue);
        }
    }

    // Liberar memoria de ResponseData_ptr
    if(ResponseData_ptr != NULL) {
        FreePool(ResponseData_ptr);
    }

    gBS->CloseEvent(ResponseToken.Event);

    //========================================================================
    // PASO 2: Recibir BODY
    //========================================================================
    Print(L"\n[!!!] Paso 2: Recibiendo body HTTP...\n");

    // Asignar buffer para el body
    Buffer = AllocateZeroPool(BufferSize);
    if(Buffer == NULL) {
        Print(L"[ERROR]: No se pudo asignar buffer para body :(\n");
        return EFI_OUT_OF_RESOURCES;
    }

    ZeroMem(&ResponseToken, sizeof(ResponseToken));
    ZeroMem(&ResponseMessage, sizeof(ResponseMessage));
    ResponseDone = FALSE;

    // Crear nuevo evento para el body
    Status = gBS->CreateEvent(EVT_NOTIFY_SIGNAL,
                              TPL_CALLBACK,
                              HttpResponseCallback,
                              &ResponseDone,
                              &ResponseToken.Event);

    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: No se pudo crear evento para body :( => %r\n", Status);
        FreePool(Buffer);
        return Status;
    }

    // Ahora recibimos el body
    ResponseMessage.Data.Response = NULL;
    ResponseMessage.HeaderCount = 0;
    ResponseMessage.Headers = NULL;
    ResponseMessage.BodyLength = BufferSize;
    ResponseMessage.Body = Buffer;

    ResponseToken.Status = EFI_NOT_READY;
    ResponseToken.Message = &ResponseMessage;

    // Llamar a Response para body
    Status = mHttpProtocol->Response(mHttpProtocol, &ResponseToken);
    if(EFI_ERROR(Status)) {
        Print(L"[ERROR]: error en 'Response()' para *body* :( => %r\n", Status);
        gBS->CloseEvent(ResponseToken.Event);
        FreePool(Buffer);
        return Status;
    }

    // Esperar body con polling activo
    TimeElapsed = 0;
    while(!ResponseDone && TimeElapsed < TimeoutMs) {
        mHttpProtocol->Poll(mHttpProtocol);
        gBS->Stall(1000);
        TimeElapsed += 1;

        if(TimeElapsed % 1000 == 0) {
            Print(L"    ... esperando body [%d]s\n", TimeElapsed / 1000);
        }
    }

    if(!ResponseDone) {
        Print(L"[ERROR]: Timeout recibiendo body HTTP\n");
        mHttpProtocol->Cancel(mHttpProtocol, &ResponseToken);
        gBS->CloseEvent(ResponseToken.Event);
        FreePool(Buffer);
        return EFI_TIMEOUT;
    }

    if(EFI_ERROR(ResponseToken.Status)) {
        Print(L"[ERROR]: error recibiendo body :( => %r\n", ResponseToken.Status);
        gBS->CloseEvent(ResponseToken.Event);
        FreePool(Buffer);
        return ResponseToken.Status;
    }

    // Copiar datos del body
    *ResponseLength = ResponseMessage.BodyLength;
    *ResponseData = AllocateZeroPool(*ResponseLength);
    if(*ResponseData == NULL) {
        Print(L"[ERROR]: No se pudo asignar memoria para ResponseData :(\n");
        gBS->CloseEvent(ResponseToken.Event);
        FreePool(Buffer);
        return EFI_OUT_OF_RESOURCES;
    }
    CopyMem(*ResponseData, Buffer, *ResponseLength);

    Print(L"[OK] Body HTTP recibido: [%d] bytes en [%d] ms.\n", *ResponseLength, TimeElapsed);

    gBS->CloseEvent(ResponseToken.Event);
    FreePool(Buffer);
    return EFI_SUCCESS;
}
