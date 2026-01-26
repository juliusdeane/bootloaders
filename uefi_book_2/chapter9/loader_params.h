#ifndef LOADER_PARAMS_H
#define LOADER_PARAMS_H

typedef struct {
    EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE  *GPUArray;             // An array of EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE structs defining each available framebuffer
    UINT64                              NumberOfFrameBuffers; // The number of structs in the array (== the number of available framebuffers)
} GPU_CONFIG;


typedef struct {
    UINT32                    UEFI_Version;                   // The system UEFI version
    UINT32                    Bootloader_MajorVersion;        // The major version of the bootloader
    UINT32                    Bootloader_MinorVersion;        // The minor version of the bootloader

    UINT32                    Memory_Map_Descriptor_Version;  // The memory descriptor version
    UINTN                     Memory_Map_Descriptor_Size;     // The size of an individual memory descriptor
    EFI_MEMORY_DESCRIPTOR    *Memory_Map;                     // The system memory map as an array of EFI_MEMORY_DESCRIPTOR structs
    UINTN                     Memory_Map_Size;                // The total size of the system memory map

    EFI_PHYSICAL_ADDRESS      Kernel_BaseAddress;             // The base memory address of the loaded kernel file
    UINTN                     Kernel_Pages;                   // The number of pages (1 page == 4096 bytes) allocated for the kernel file

    CHAR16                   *ESP_Root_Device_Path;           // A UTF-16 string containing the drive root of the EFI System Partition as converted from UEFI device path format
    UINT64                    ESP_Root_Size;                  // The size (in bytes) of the above ESP root string
    CHAR16                   *Kernel_Path;                    // A UTF-16 string containing the kernel's file path relative to the EFI System Partition root (it's the first line of Kernel64.txt)
    UINT64                    Kernel_Path_Size;               // The size (in bytes) of the above kernel file path
    CHAR16                   *Kernel_Options;                 // A UTF-16 string containing various load options (it's the second line of Kernel64.txt)
    UINT64                    Kernel_Options_Size;            // The size (in bytes) of the above load options string

    EFI_RUNTIME_SERVICES     *RTServices;                     // UEFI Runtime Services
    GPU_CONFIG               *GPU_Configs;                    // Information about available graphics output devices; see below GPU_CONFIG struct for details
    EFI_FILE_INFO            *FileMeta;                       // Kernel file metadata
    EFI_CONFIGURATION_TABLE  *ConfigTables;                   // UEFI-installed system configuration tables (ACPI, SMBIOS, etc.)
    UINTN                     Number_of_ConfigTables;         // The number of system configuration tables
} LOADER_PARAMS;

#endif