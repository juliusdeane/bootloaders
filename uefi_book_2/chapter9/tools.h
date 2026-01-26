#ifndef TOOLS_H
#define TOOLS_H

#include <efi.h>
#include <efilib.h>


VOID Hex_Dump (IN VOID *Buffer, IN UINTN Size);

VOID Halt_Execution(VOID);

EFI_STATUS set_efi_variable(CHAR16 *VariableName,
                            EFI_GUID *TargetGuid,
                            UINT32 Attributes,
                            UINTN DataSize,
                            VOID *Data);

EFI_STATUS get_efi_variable(CHAR16 *VariableName,
                            EFI_GUID *TargetGuid,
                            VOID **Data,
                            UINTN *DataSize);

EFI_STATUS delete_efi_variable(CHAR16 *VariableName,
                               EFI_GUID *TargetGuid);

EFI_STATUS Load_File(EFI_FILE_PROTOCOL *Root, CHAR16 *Path, VOID **Buffer, UINTN *Size);

#endif