#include <efi.h>
#include <efilib.h>
#include <eficon.h>


extern "C" [[noreturn]][[gnu::ms_abi]] EFI_STATUS
efi_main(IN EFI_HANDLE imageHandle,
         IN EFI_SYSTEM_TABLE *SystemTable) {
    while (TRUE) {}
}
