;*****************************************************************************
; Imprime los valores que encontramos en bruto en el kernel:
; - se leen desde 0x1000000 (16MB).
;*****************************************************************************
kernel_staging_debug_values:
    pusha

    call separator
    mov si, msg_st_open_debug
    call debug_print_string
    ;**************************************************************************
    ; DEBUG fields.
    ;**************************************************************************
    ; setup_sects:
    mov si, msg_st_header_1f1
    call debug_print_string
    mov edi, 0x10001f1
    movzx ebx, byte [edi]
    call print_hex_serial

    ; root_flags:
    mov si, msg_st_header_1f2
    call debug_print_string
    mov edi, 0x10001f2
    movzx ebx, word [edi]
    call print_hex_serial

    ; root_flags:
    mov si, msg_st_header_1f4
    call debug_print_string
    mov edi, 0x10001f4
    mov ebx, [edi]
    call print_hex_serial

    ; vid_mode:
    mov si, msg_st_header_1fa
    call debug_print_string
    mov edi, 0x10001fa
    movzx ebx, word [edi]
    call print_hex_serial

    ; boot_flag: jmp
    mov si, msg_st_header_200
    call debug_print_string
    mov edi, 0x1000200
    movzx ebx, word [edi]
    call print_hex_serial

    ; boot_flag: 0xaa55
    mov si, msg_st_header_1fe
    call debug_print_string
    mov edi, 0x10001fe
    movzx ebx, word [edi]
    call print_hex_serial

    ; header: "HdrS"
    mov si, msg_st_header_202
    call debug_print_string
    mov edi, 0x1000202
    mov ebx, [edi]
    call print_hex_serial

    ; version:
    mov si, msg_st_header_206
    call debug_print_string
    mov edi, 0x1000206
    movzx ebx, word [edi]
    call print_hex_serial

    ; realmode_swtch:
    mov si, msg_st_header_208
    call debug_print_string
    mov edi, 0x1000208
    mov ebx, [edi]
    call print_hex_serial

    ; kernel_version:
    mov si, msg_st_header_20e
    call debug_print_string
    mov edi, 0x100020e
    movzx ebx, word [edi]
    call print_hex_serial

    ; type_of_loader:
    mov si, msg_st_header_210
    call debug_print_string
    mov edi, 0x1000210
    movzx ebx, byte [edi]
    call print_hex_serial

    ; loadflags:
    mov si, msg_st_header_211
    call debug_print_string
    mov edi, 0x1000211
    movzx ebx, byte [edi]
    call print_hex_serial

    ; setup_move_size:
    mov si, msg_st_header_212
    call debug_print_string
    mov edi, 0x1000212
    movzx ebx, word [edi]
    call print_hex_serial

    ; code32_start:
    mov si, msg_st_header_214
    call debug_print_string
    mov edi, 0x1000214
    mov ebx, [edi]
    call print_hex_serial

    ; ramdisk_image:
    mov si, msg_st_header_218
    call debug_print_string
    mov edi, 0x1000218
    mov ebx, [edi]
    call print_hex_serial

    ; ramdisk_size:
    mov si, msg_st_header_21c
    call debug_print_string
    mov edi, 0x100021c
    mov ebx, [edi]
    call print_hex_serial

    ; heap_end_ptr:
    mov si, msg_st_header_224
    call debug_print_string
    mov edi, 0x1000224
    movzx ebx, word [edi]
    call print_hex_serial

    ; ext_loader_ver:
    mov si, msg_st_header_226
    call debug_print_string
    mov edi, 0x1000226
    movzx ebx, byte [edi]
    call print_hex_serial

    ; ext_loader_type:
    mov si, msg_st_header_227
    call debug_print_string
    mov edi, 0x1000227
    movzx ebx, byte [edi]
    call print_hex_serial

    ; cmd_line_ptr:
    mov si, msg_st_header_228
    call debug_print_string
    mov edi, 0x1000228
    mov ebx, [edi]
    call print_hex_serial

    ; initrd_addr_max:
    mov si, msg_st_header_22c
    call debug_print_string
    mov edi, 0x100022c
    mov ebx, [edi]
    call print_hex_serial

    ; kernel_alignment:
    mov si, msg_st_header_230
    call debug_print_string
    mov edi, 0x1000230
    mov ebx, [edi]
    call print_hex_serial

    ; relocatable_kernel:
    mov si, msg_st_header_234
    call debug_print_string
    mov edi, 0x1000234
    movzx ebx, byte [edi]
    call print_hex_serial

    ; min_alignment:
    mov si, msg_st_header_235
    call debug_print_string
    mov edi, 0x1000235
    movzx ebx, byte [edi]
    call print_hex_serial

    ; xloadflags:
    mov si, msg_st_header_236
    call debug_print_string
    mov edi, 0x1000236
    movzx ebx, word [edi]
    call print_hex_serial

    ; cmdline_size:
    mov si, msg_st_header_238
    call debug_print_string
    mov edi, 0x1000238
    mov ebx, [edi]
    call print_hex_serial

    ; hardware_subarch:
    mov si, msg_st_header_23c
    call debug_print_string
    mov edi, 0x100023c
    mov ebx, [edi]
    call print_hex_serial

    ; hardware_subarch_data:
    mov si, msg_st_header_240
    call debug_print_string
    mov edi, 0x1000240
    mov ebx, dword [edi]  ; 8 bytes!
    call print_hex_serial

    ; payload_offset:
    mov si, msg_st_header_248
    call debug_print_string
    mov edi, 0x1000248
    mov ebx, [edi]
    call print_hex_serial

    ; payload_length:
    mov si, msg_st_header_24c
    call debug_print_string
    mov edi, 0x100024c
    mov ebx, [edi]
    call print_hex_serial

    ; setup_data:
    mov si, msg_st_header_250
    call debug_print_string
    mov edi, 0x1000250
    mov ebx, dword [edi]  ; 8 bytes!
    call print_hex_serial

    ; pref_address:
    mov si, msg_st_header_258
    call debug_print_string
    mov edi, 0x1000258
    mov ebx, dword [edi]  ; 8 bytes!
    call print_hex_serial

    ; init_size:
    mov si, msg_st_header_260
    call debug_print_string
    mov edi, 0x1000260
    mov ebx, [edi]
    call print_hex_serial

    ; handover_offset:
    mov si, msg_st_header_264
    call debug_print_string
    mov edi, 0x1000264
    mov ebx, [edi]
    call print_hex_serial

    ; kernel_info_offset:
    mov si, msg_st_header_268
    call debug_print_string
    mov edi, 0x1000268
    mov ebx, [edi]
    call print_hex_serial
    ;**************************************************************************
    ; //END: DEBUG fields.
    ;**************************************************************************
    mov si, msg_st_end_debug
    call debug_print_string
    call separator

    popa
    ret

;*****************************************************************************
; Imprime los valores que encontramos en el kernel header:
; - algunos los hemos escrito nosotros.
; - se leen desde 0x90000.
;*****************************************************************************
kernel_running_debug_values:
    pusha

    call separator
    mov si, msg_ru_open_debug
    call debug_print_string
    ;**************************************************************************
    ; DEBUG fields.
    ;**************************************************************************
    ; setup_sects:
    mov si, msg_ru_header_1f1
    call debug_print_string
    mov edi, 0x01f1
    movzx ebx, byte [edi]
    call print_hex_serial

    ; root_flags:
    mov si, msg_ru_header_1f2
    call debug_print_string
    mov edi, 0x01f2
    movzx ebx, word [edi]
    call print_hex_serial

    ; root_flags:
    mov si, msg_ru_header_1f4
    call debug_print_string
    mov edi, 0x01f4
    mov ebx, [edi]
    call print_hex_serial

    ; vid_mode:
    mov si, msg_ru_header_1fa
    call debug_print_string
    mov edi, 0x01fa
    movzx ebx, word [edi]
    call print_hex_serial

    ; boot_flag: jmp
    mov si, msg_ru_header_200
    call debug_print_string
    mov edi, 0x0200
    movzx ebx, word [edi]
    call print_hex_serial

    ; boot_flag: 0xaa55
    mov si, msg_ru_header_1fe
    call debug_print_string
    mov edi, 0x01fe
    movzx ebx, word [edi]
    call print_hex_serial

    ; header: "HdrS"
    mov si, msg_ru_header_202
    call debug_print_string
    mov edi, 0x0202
    mov ebx, [edi]
    call print_hex_serial

    ; version:
    mov si, msg_ru_header_206
    call debug_print_string
    mov edi, 0x0206
    movzx ebx, word [edi]
    call print_hex_serial

    ; realmode_swtch:
    mov si, msg_ru_header_208
    call debug_print_string
    mov edi, 0x0208
    mov ebx, [edi]
    call print_hex_serial

    ; kernel_version:
    mov si, msg_ru_header_20e
    call debug_print_string
    mov edi, 0x020e
    movzx ebx, word [edi]
    call print_hex_serial

    ; type_of_loader:
    mov si, msg_ru_header_210
    call debug_print_string
    mov edi, 0x0210
    movzx ebx, byte [edi]
    call print_hex_serial

    ; loadflags:
    mov si, msg_ru_header_211
    call debug_print_string
    mov edi, 0x0211
    movzx ebx, byte [edi]
    call print_hex_serial

    ; setup_move_size:
    mov si, msg_ru_header_212
    call debug_print_string
    mov edi, 0x0212
    movzx ebx, word [edi]
    call print_hex_serial

    ; code32_start:
    mov si, msg_ru_header_214
    call debug_print_string
    mov edi, 0x0214
    mov ebx, [edi]
    call print_hex_serial

    ; ramdisk_image:
    mov si, msg_ru_header_218
    call debug_print_string
    mov edi, 0x0218
    mov ebx, [edi]
    call print_hex_serial

    ; ramdisk_size:
    mov si, msg_ru_header_21c
    call debug_print_string
    mov edi, 0x021c
    mov ebx, [edi]
    call print_hex_serial

    ; heap_end_ptr:
    mov si, msg_ru_header_224
    call debug_print_string
    mov edi, 0x0224
    movzx ebx, word [edi]
    call print_hex_serial

    ; ext_loader_ver:
    mov si, msg_ru_header_226
    call debug_print_string
    mov edi, 0x0226
    movzx ebx, byte [edi]
    call print_hex_serial

    ; ext_loader_type:
    mov si, msg_ru_header_227
    call debug_print_string
    mov edi, 0x0227
    movzx ebx, byte [edi]
    call print_hex_serial

    ; cmd_line_ptr:
    mov si, msg_ru_header_228
    call debug_print_string
    mov edi, 0x0228
    mov ebx, [edi]
    call print_hex_serial

    ; initrd_addr_max:
    mov si, msg_ru_header_22c
    call debug_print_string
    mov edi, 0x022c
    mov ebx, [edi]
    call print_hex_serial

    ; kernel_alignment:
    mov si, msg_ru_header_230
    call debug_print_string
    mov edi, 0x0230
    mov ebx, [edi]
    call print_hex_serial

    ; relocatable_kernel:
    mov si, msg_ru_header_234
    call debug_print_string
    mov edi, 0x0234
    movzx ebx, byte [edi]
    call print_hex_serial

    ; min_alignment:
    mov si, msg_ru_header_235
    call debug_print_string
    mov edi, 0x0235
    movzx ebx, byte [edi]
    call print_hex_serial

    ; xloadflags:
    mov si, msg_ru_header_236
    call debug_print_string
    mov edi, 0x0236
    movzx ebx, word [edi]
    call print_hex_serial

    ; cmdline_size:
    mov si, msg_ru_header_238
    call debug_print_string
    mov edi, 0x0238
    mov ebx, [edi]
    call print_hex_serial

    ; hardware_subarch:
    mov si, msg_ru_header_23c
    call debug_print_string
    mov edi, 0x023c
    mov ebx, [edi]
    call print_hex_serial

    ; hardware_subarch_data:
    mov si, msg_ru_header_240
    call debug_print_string
    mov edi, 0x0240
    mov ebx, dword [edi]  ; 8 bytes!
    call print_hex_serial

    ; payload_offset:
    mov si, msg_ru_header_248
    call debug_print_string
    mov edi, 0x0248
    mov ebx, [edi]
    call print_hex_serial

    ; payload_length:
    mov si, msg_ru_header_24c
    call debug_print_string
    mov edi, 0x024c
    mov ebx, [edi]
    call print_hex_serial

    ; setup_data:
    mov si, msg_ru_header_250
    call debug_print_string
    mov edi, 0x0250
    mov ebx, dword [edi]  ; 8 bytes!
    call print_hex_serial

    ; pref_address:
    mov si, msg_ru_header_258
    call debug_print_string
    mov edi, 0x0258
    mov ebx, dword [edi]  ; 8 bytes!
    call print_hex_serial

    ; init_size:
    mov si, msg_ru_header_260
    call debug_print_string
    mov edi, 0x0260
    mov ebx, [edi]
    call print_hex_serial

    ; handover_offset:
    mov si, msg_ru_header_264
    call debug_print_string
    mov edi, 0x0264
    mov ebx, [edi]
    call print_hex_serial

    ; kernel_info_offset:
    mov si, msg_ru_header_268
    call debug_print_string
    mov edi, 0x0268
    mov ebx, [edi]
    call print_hex_serial
    ;**************************************************************************
    ; //END: DEBUG fields.
    ;**************************************************************************
    mov si, msg_ru_end_debug
    call debug_print_string

    call separator

    popa
    ret
