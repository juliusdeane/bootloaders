#ifndef LINUX_H
#define LINUX_H

#include <efi.h>
#include <efilib.h>

// Para verificar soporte de handover 64-bit
#define XLF_KERNEL_64               (1<<0)
#define XLF_CAN_BE_LOADED_ABOVE_4G  (1<<1)
#define XLF_EFI_HANDOVER_32         (1<<2)
#define XLF_EFI_HANDOVER_64         (1<<3)

#define E820_RAM        1
#define E820_RESERVED   2
#define E820_ACPI       3
#define E820_NVS        4
#define E820_UNUSABLE   5
#define E820_MAX        128


typedef struct {
    UINT8 setup_sects;
    UINT16 root_flags;
    UINT32 syssize;
    UINT16 ram_size;
    UINT16 vid_mode;
    UINT16 root_dev;
    UINT16 boot_flag;
    UINT16 jump;
    UINT32 header;
    UINT16 version;
    UINT32 realmode_swtch;
    UINT16 start_sys_seg;
    UINT16 kernel_version;
    UINT8 type_of_loader;
    UINT8 loadflags;
    UINT16 setup_move_size;
    UINT32 code32_start;
    UINT32 ramdisk_image;
    UINT32 ramdisk_size;
    UINT32 bootsect_kludge;
    UINT16 heap_end_ptr;
    UINT8 ext_loader_ver;
    UINT8 ext_loader_type;
    UINT32 cmd_line_ptr;
    UINT32 initrd_addr_max;
    UINT32 kernel_alignment;
    UINT8 relocatable_kernel;
    UINT8 min_alignment;
    UINT16 xloadflags;
    UINT32 cmdline_size;
    UINT32 hardware_subarch;
    UINT64 hardware_subarch_data;
    UINT32 payload_offset;
    UINT32 payload_length;
    UINT64 setup_data;
    UINT64 pref_address;
    UINT32 init_size;
    UINT32 handover_offset;
} __attribute__((packed)) LinuxKernelSetupHeader;


// Entrada E820
typedef struct  {
    UINT64 addr;
    UINT64 size;
    UINT32 type;
} __attribute__((packed)) e820Entry;


// Estructura boot_params COMPLETA
typedef struct {
    UINT8                      _pad1[0x1e8];                    // Offset 0x000
    UINT8                      e820_entries;                    // Offset 0x1e8
    UINT8                      _pad2[0x1ef - 0x1e9];            // Padding
    LinuxKernelSetupHeader     hdr;                             // Offset 0x1f1
    UINT8                      _pad3[0x290 - 0x1f1 - sizeof(LinuxKernelSetupHeader)];
    UINT32                     edd_mbr_sig_buffer[16];          // Offset 0x290
    e820Entry                  e820_table[E820_MAX];            // Offset 0x2d0
    UINT8                      _pad4[0x1000 - 0x2d0 - (E820_MAX * sizeof(e820Entry))];
} __attribute__((packed)) LinuxBootParams;


// Tipo de función handover para x86_64
//void handover_64(void *image_handle, struct boot_params *params, void *unused)
//typedef void (*handover_function)(VOID *image,
//                                  EFI_SYSTEM_TABLE *table,
//                                  struct LinuxBootParams *bp);
typedef void (*handover_function)(VOID *image,
                                  struct LinuxBootParams *bp,
                                  VOID *unused);


#endif