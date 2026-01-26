#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>

VOID Halt_Execution(VOID);

//****************************************************************************
// EFI_MAIN:
//****************************************************************************
EFI_STATUS EFIAPI UefiMain (IN EFI_HANDLE ImageHandle,IN EFI_SYSTEM_TABLE  *SystemTable) {
    EFI_STATUS  Status = EFI_SUCCESS;

    Print(L"Prueba de Print con EDK II:\n");
    Print(L"%hhs", "");
    Print(L"1 - %hgs\r\n", "");
    Print(L"2 - %hls\r\n", "");
    Print(L"3 - %hms\r\n", "");
    Print(L"4 - %hns\r\n", "");
    Print(L"5 - %hñs\r\n", "");
    Print(L"6 - %hos\r\n", "");
    Print(L"7 - %hps\r\n", "");
    Print(L"8 - %hqs\r\n", "");
    Print(L"9 - %hrs\r\n", "");
    Print(L"10 - %hss\r\n", "");
    Print(L"11 - %hts\r\n", "");
    Print(L"12 - %hus\r\n", "");
    Print(L"13 - %hvs\r\n", "");
    Print(L"15 - %hws\r\n", "");
    Print(L"16 - %hxs\r\n", "");
    Print(L"17 - %hys\r\n", "");
    Print(L"18 - %hzs\r\n", "");

    Print(L"    => Veamos el color de esta cadena de texto para confirmar...\n");

    Halt_Execution();

    return Status;
}
//****************************************************************************
// FIN: EFI_MAIN.
//****************************************************************************


VOID Halt_Execution(VOID) {
    while (TRUE) {
        // En EDK II, es mejor usar una llamada que no consuma CPU
        gBS->Stall (1000000);  // Esperar 1 segundo
        // Igualmente invocamos HALT.
        asm volatile("hlt");
    }
}