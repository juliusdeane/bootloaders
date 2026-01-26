#ifndef DOS_PE_H
#define DOS_PE_H

// Estas estructutas las he sacado de:
// https://github.com/u-boot/u-boot/blob/master/include/pe.h
typedef struct _IMAGE_DOS_HEADER {
    UINT16 e_magic;	    /* 00: MZ Header signature */
    UINT16 e_cblp;	    /* 02: Bytes on last page of file */
    UINT16 e_cp;		/* 04: Pages in file */
    UINT16 e_crlc;	    /* 06: Relocations */
    UINT16 e_cparhdr;	/* 08: Size of header in paragraphs */
    UINT16 e_minalloc;	/* 0a: Minimum extra paragraphs needed */
    UINT16 e_maxalloc;	/* 0c: Maximum extra paragraphs needed */
    UINT16 e_ss;		/* 0e: Initial (relative) SS value */
    UINT16 e_sp;		/* 10: Initial SP value */
    UINT16 e_csum;	    /* 12: Checksum */
    UINT16 e_ip;		/* 14: Initial IP value */
    UINT16 e_cs;		/* 16: Initial (relative) CS value */
    UINT16 e_lfarlc;	/* 18: File address of relocation table */
    UINT16 e_ovno;	    /* 1a: Overlay number */
    UINT16 e_res[4];	/* 1c: Reserved words */
    UINT16 e_oemid;	    /* 24: OEM identifier (for e_oeminfo) */
    UINT16 e_oeminfo;	/* 26: OEM information; e_oemid specific */
    UINT16 e_res2[10];	/* 28: Reserved words */
    UINT32 e_lfanew;	/* 3c: Offset to extended header */
} IMAGE_DOS_HEADER, *PIMAGE_DOS_HEADER;

typedef struct _IMAGE_FILE_HEADER {
    UINT16  Machine;
    UINT16  NumberOfSections;
    UINT32  TimeDateStamp;
    UINT32  PointerToSymbolTable;
    UINT32  NumberOfSymbols;
    UINT16  SizeOfOptionalHeader;
    UINT16  Characteristics;
} IMAGE_FILE_HEADER, *PIMAGE_FILE_HEADER;

typedef struct _IMAGE_DATA_DIRECTORY {
    UINT32  VirtualAddress;
    UINT32  Size;
} IMAGE_DATA_DIRECTORY, *PIMAGE_DATA_DIRECTORY;

#define IMAGE_NUMBEROF_DIRECTORY_ENTRIES  16

typedef struct _IMAGE_OPTIONAL_HEADER64 {
    UINT16 Magic; /* 0x20b */
    UINT8  MajorLinkerVersion;
    UINT8  MinorLinkerVersion;
    UINT32 SizeOfCode;
    UINT32 SizeOfInitializedData;
    UINT32 SizeOfUninitializedData;
    UINT32 AddressOfEntryPoint;
    UINT32 BaseOfCode;
    UINT64 ImageBase;
    UINT32 SectionAlignment;
    UINT32 FileAlignment;
    UINT16 MajorOperatingSystemVersion;
    UINT16 MinorOperatingSystemVersion;
    UINT16 MajorImageVersion;
    UINT16 MinorImageVersion;
    UINT16 MajorSubsystemVersion;
    UINT16 MinorSubsystemVersion;
    UINT32 Win32VersionValue;
    UINT32 SizeOfImage;
    UINT32 SizeOfHeaders;
    UINT32 CheckSum;
    UINT16 Subsystem;
    UINT16 DllCharacteristics;
    UINT64 SizeOfStackReserve;
    UINT64 SizeOfStackCommit;
    UINT64 SizeOfHeapReserve;
    UINT64 SizeOfHeapCommit;
    UINT32 LoaderFlags;
    UINT32 NumberOfRvaAndSizes;
    IMAGE_DATA_DIRECTORY DataDirectory[IMAGE_NUMBEROF_DIRECTORY_ENTRIES];
} IMAGE_OPTIONAL_HEADER64, *PIMAGE_OPTIONAL_HEADER64;

typedef struct _IMAGE_NT_HEADERS64 {
    UINT32                   Signature;
    IMAGE_FILE_HEADER        FileHeader;
    IMAGE_OPTIONAL_HEADER64  OptionalHeader;
} IMAGE_NT_HEADERS64, *PIMAGE_NT_HEADERS64;

// https://github.com/tianocore/edk2/blob/master/MdePkg/Include/IndustryStandard/PeImage.h
#define EFI_IMAGE_SUBSYSTEM_EFI_APPLICATION          10
#define EFI_IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER  11
#define EFI_IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER       12

#define IMAGE_FILE_MACHINE_I386            0x014c
#define IMAGE_FILE_MACHINE_IA64            0x0200
#define IMAGE_FILE_MACHINE_EBC             0x0EBC
#define IMAGE_FILE_MACHINE_X64             0x8664
#define IMAGE_FILE_MACHINE_ARMTHUMB_MIXED  0x01c2
#define IMAGE_FILE_MACHINE_ARM64           0xAA64
#define IMAGE_FILE_MACHINE_RISCV32         0x5032
#define IMAGE_FILE_MACHINE_RISCV64         0x5064
#define IMAGE_FILE_MACHINE_RISCV128        0x5128
#define IMAGE_FILE_MACHINE_LOONGARCH32     0x6232
#define IMAGE_FILE_MACHINE_LOONGARCH64     0x6264

#define EFI_IMAGE_NT_OPTIONAL_HDR32_MAGIC  0x10b
#define EFI_IMAGE_NT_OPTIONAL_HDR64_MAGIC  0x20b

#endif
