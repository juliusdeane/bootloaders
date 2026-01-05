;*****************************************************************************
; MENSAJES PREVIOS DE KERNEL:
;*****************************************************************************
msg_bad_setup:            db '[KERNEL] Error en el setup:', 13, 10, 0
msg_kernel_bp_version:    db '[KERNEL] Boot protocol version:', 13, 10, 0
msg_kernel_syssize:       db '[KERNEL] Kernel syssize original:', 13, 10, 0
msg_kernel_syssize_shl:   db '[KERNEL] Kernel syssize (tras shl):', 13, 10, 0
msg_bad_protocol:         db '[KERNEL] Protocolo incorrecto:', 13, 10, 0
msg_kernel_begin_load:    db '[KERNEL] Inicia carga del kernel:', 13, 10, 0
msg_kernel_loaded:        db '[KERNEL] Kernel cargado!', 13, 10, 0

msg_initrd_begin_load:    db '[INITRD] Inicia carga de initrd:', 13, 10, 0
msg_initrd_loaded:        db '[INITRD] Initrd cargado!', 13, 10, 0
msg_initrd_begin:         db '[INITRD] Empieza en:', 13, 10, 0
msg_initrd_end:           db '[INITRD] Termina en:', 13, 10, 0

msg_setup_load:           db 13, 10, '[KERNEL] Setup cargando:', 13, 10, 0
msg_setup_ok:             db '[KERNEL] Setup correcto!', 13, 10, 0
msg_setup_copy:           db 13, 10, '[KERNEL] Copiando setup a su sitio:', 13, 10, 0
msg_setup_copy_ok:        db '[KERNEL] Setup copiado.', 13, 10, 0
msg_setup_copy_check:     db '[KERNEL] Verificamos copia de setup:', 13, 10, 0
msg_setup_copy_check_ok:  db '[KERNEL] Copia de setup verificada:', 13, 10, 0
msg_setup_check_jmp:      db '[KERNEL] setup => jmp 0x9026c en +0x200:', 13, 10, 0

msg_payload_load:         db 13, 10, '[KERNEL] Payload cargando:', 13, 10, 0
msg_payload_start_at:     db '[KERNEL] Payload empieza en:', 13, 10, 0
msg_payload_ok:           db '[KERNEL] Payload correcto!', 13, 10, 0

msg_loadflags_check:      db '[KERNEL] Verificar loadflags:', 13, 10, 0
msg_heap_end_check:       db '[KERNEL] Verificar heap_end_ptr:', 13, 10, 0
msg_bp_version_check:     db '[KERNEL] Verificar Boot Protocol version:', 13, 10, 0
msg_bootloader_check:     db '[KERNEL] Verificar Bootloader ID:', 13, 10, 0

msg_debug_code32_start:   db '[KERNEL] [DEBUG] code32_start:', 13, 10, 0
msg_debug_cmd_line_ptr:   db '[KERNEL] [DEBUG] cmd_line_ptr:', 13, 10, 0
msg_debug_ramdisk_image:  db '[KERNEL] [DEBUG] ramdisk_image:', 13, 10, 0
msg_debug_ramdisk_size:   db '[KERNEL] [DEBUG] ramdisk_size:', 13, 10, 0
msg_debug_loadflags:      db '[KERNEL] [DEBUG] loadflags:', 13, 10, 0
msg_debug_heap_end:       db '[KERNEL] [DEBUG] heap_end_ptr:', 13, 10, 0
msg_kernel_ready:         db 13, 10, '[KERNEL] TODO OK? => PRE jmp', 13, 10, 0

msg_kernel_setup_sects:   db 13, 10, '[KERNEL] setup_sects:', 13, 10, 0
msg_kernel_setup_size_final:  db '[KERNEL] setup_size calculado:', 13, 10, 0

;*****************************************************************************
; STAGING:
;*****************************************************************************
; NG: estas cadenas ahora caben en el espacio de stage2.
msg_st_open_debug:        db '[STAGING] [KERNEL] === START DEBUG INFORMATION ===', 13, 10, 0
msg_st_end_debug:         db '[STAGING] [KERNEL] ==== END DEBUG INFORMATION ====', 13, 10, 0

msg_st_header_1f1:        db '[STAGING] [KERNEL] setup_sects=[0x01f1]:', 13, 10, 0
msg_st_header_1f2:        db '[STAGING] [KERNEL] root_flags=[0x01f2]:', 13, 10, 0
msg_st_header_1f4:        db '[STAGING] [KERNEL] syssize=[0x01f4]:', 13, 10, 0
; msg_st_header_1f8:        db '[STAGING] [KERNEL] ram_size=[0x01f8]:', 13, 10, 0
msg_st_header_1fa:        db '[STAGING] [KERNEL] vid_mode=[0x01fa]:', 13, 10, 0
msg_st_header_1fe:        db '[STAGING] [KERNEL] boot_flag=[0x01fe] (0xaa55):', 13, 10, 0
msg_st_header_200:        db '[STAGING] [KERNEL] jump=[0x0200]:', 13, 10, 0
msg_st_header_202:        db '[STAGING] [KERNEL] HdrS=[0x0202]:', 13, 10, 0
msg_st_header_206:        db '[STAGING] [KERNEL] version=[0x0206]:', 13, 10, 0
msg_st_header_208:        db '[STAGING] [KERNEL] realmode_swtch=[0x0208]:', 13, 10, 0
; msg_st_header_20c:        db '[STAGING] [KERNEL] start_sys_seg=[0x020c]:', 13, 10, 0
msg_st_header_20e:        db '[STAGING] [KERNEL] kernel_version=[0x020e]:', 13, 10, 0
msg_st_header_210:        db '[STAGING] [KERNEL] type_of_loader=[0x0210]:', 13, 10, 0
msg_st_header_211:        db '[STAGING] [KERNEL] loadflags=[0x0211]:', 13, 10, 0
msg_st_header_212:        db '[STAGING] [KERNEL] setup_move_size=[0x0212]:', 13, 10, 0
msg_st_header_214:        db '[STAGING] [KERNEL] code32_start=[0x0214]:', 13, 10, 0
msg_st_header_218:        db '[STAGING] [KERNEL] ramdisk_image=[0x0218]:', 13, 10, 0
msg_st_header_21c:        db '[STAGING] [KERNEL] ramdisk_size=[0x021c]:', 13, 10, 0
; msg_st_header_220:        db '[STAGING] [KERNEL] bootsect_kludge=[0x0220]:', 13, 10, 0
msg_st_header_224:        db '[STAGING] [KERNEL] heap_end_ptr=[0x0224]:', 13, 10, 0
msg_st_header_226:        db '[STAGING] [KERNEL] ext_loader_ver=[0x0226]:', 13, 10, 0
msg_st_header_227:        db '[STAGING] [KERNEL] ext_loader_type=[0x0227]:', 13, 10, 0
msg_st_header_228:        db '[STAGING] [KERNEL] cmd_line_ptr=[0x0228]:', 13, 10, 0
msg_st_header_22c:        db '[STAGING] [KERNEL] initrd_addr_max=[0x022c]:', 13, 10, 0
msg_st_header_230:        db '[STAGING] [KERNEL] kernel_alignment=[0x0230]:', 13, 10, 0
msg_st_header_234:        db '[STAGING] [KERNEL] relocatable_kernel=[0x0234]:', 13, 10, 0
msg_st_header_235:        db '[STAGING] [KERNEL] min_alignment=[0x0235]:', 13, 10, 0
msg_st_header_236:        db '[STAGING] [KERNEL] xloadflags=[0x0236]:', 13, 10, 0
msg_st_header_238:        db '[STAGING] [KERNEL] cmdline_size=[0x0238]:', 13, 10, 0
msg_st_header_23c:        db '[STAGING] [KERNEL] hardware_subarch=[0x023c]:', 13, 10, 0
msg_st_header_240:        db '[STAGING] [KERNEL] hardware_subarch_data=[0x0240]:', 13, 10, 0
msg_st_header_248:        db '[STAGING] [KERNEL] payload_offset=[0x0248]:', 13, 10, 0
msg_st_header_24c:        db '[STAGING] [KERNEL] payload_length=[0x024c]:', 13, 10, 0
msg_st_header_250:        db '[STAGING] [KERNEL] setup_data=[0x0250]:', 13, 10, 0
msg_st_header_258:        db '[STAGING] [KERNEL] pref_address=[0x0258]:', 13, 10, 0
msg_st_header_260:        db '[STAGING] [KERNEL] init_size=[0x0260]:', 13, 10, 0
msg_st_header_264:        db '[STAGING] [KERNEL] handover_offset=[0x0264]:', 13, 10, 0
msg_st_header_268:        db '[STAGING] [KERNEL] kernel_info_offset=[0x0268]:', 13, 10, 0
;*****************************************************************************
; //END: STAGING
;*****************************************************************************

;*****************************************************************************
; RUNNING:
;*****************************************************************************
msg_ru_open_debug:        db '[RUNNING] [KERNEL] === START DEBUG INFORMATION ===', 13, 10, 0
msg_ru_end_debug:         db '[RUNNING] [KERNEL] ==== END DEBUG INFORMATION ====', 13, 10, 0

msg_ru_header_1f1:        db '[RUNNING] [KERNEL] setup_sects=[0x01f1]:', 13, 10, 0
msg_ru_header_1f2:        db '[RUNNING] [KERNEL] root_flags=[0x01f2]:', 13, 10, 0
msg_ru_header_1f4:        db '[RUNNING] [KERNEL] syssize=[0x01f4]:', 13, 10, 0
; msg_ru_header_1f8:        db '[RUNNING] [KERNEL] ram_size=[0x01f8]:', 13, 10, 0
msg_ru_header_1fa:        db '[RUNNING] [KERNEL] vid_mode=[0x01fa]:', 13, 10, 0
msg_ru_header_1fe:        db '[RUNNING] [KERNEL] boot_flag=[0x01fe] (0xaa55):', 13, 10, 0
msg_ru_header_200:        db '[RUNNING] [KERNEL] jump=[0x0200]:', 13, 10, 0
msg_ru_header_202:        db '[RUNNING] [KERNEL] HdrS=[0x0202]:', 13, 10, 0
msg_ru_header_206:        db '[RUNNING] [KERNEL] version=[0x0206]:', 13, 10, 0
msg_ru_header_208:        db '[RUNNING] [KERNEL] realmode_swtch=[0x0208]:', 13, 10, 0
; msg_ru_header_20c:        db '[RUNNING] [KERNEL] start_sys_seg=[0x020c]:', 13, 10, 0
msg_ru_header_20e:        db '[RUNNING] [KERNEL] kernel_version=[0x020e]:', 13, 10, 0
msg_ru_header_210:        db '[RUNNING] [KERNEL] type_of_loader=[0x0210]:', 13, 10, 0
msg_ru_header_211:        db '[RUNNING] [KERNEL] loadflags=[0x0211]:', 13, 10, 0
msg_ru_header_212:        db '[RUNNING] [KERNEL] setup_move_size=[0x0212]:', 13, 10, 0
msg_ru_header_214:        db '[RUNNING] [KERNEL] code32_start=[0x0214]:', 13, 10, 0
msg_ru_header_218:        db '[RUNNING] [KERNEL] ramdisk_image=[0x0218]:', 13, 10, 0
msg_ru_header_21c:        db '[RUNNING] [KERNEL] ramdisk_size=[0x021c]:', 13, 10, 0
; msg_ru_header_220:        db '[RUNNING] [KERNEL] bootsect_kludge=[0x0220]:', 13, 10, 0
msg_ru_header_224:        db '[RUNNING] [KERNEL] heap_end_ptr=[0x0224]:', 13, 10, 0
msg_ru_header_226:        db '[RUNNING] [KERNEL] ext_loader_ver=[0x0226]:', 13, 10, 0
msg_ru_header_227:        db '[RUNNING] [KERNEL] ext_loader_type=[0x0227]:', 13, 10, 0
msg_ru_header_228:        db '[RUNNING] [KERNEL] cmd_line_ptr=[0x0228]:', 13, 10, 0
msg_ru_header_22c:        db '[RUNNING] [KERNEL] initrd_addr_max=[0x022c]:', 13, 10, 0
msg_ru_header_230:        db '[RUNNING] [KERNEL] kernel_alignment=[0x0230]:', 13, 10, 0
msg_ru_header_234:        db '[RUNNING] [KERNEL] relocatable_kernel=[0x0234]:', 13, 10, 0
msg_ru_header_235:        db '[RUNNING] [KERNEL] min_alignment=[0x0235]:', 13, 10, 0
msg_ru_header_236:        db '[RUNNING] [KERNEL] xloadflags=[0x0236]:', 13, 10, 0
msg_ru_header_238:        db '[RUNNING] [KERNEL] cmdline_size=[0x0238]:', 13, 10, 0
msg_ru_header_23c:        db '[RUNNING] [KERNEL] hardware_subarch=[0x023c]:', 13, 10, 0
msg_ru_header_240:        db '[RUNNING] [KERNEL] hardware_subarch_data=[0x0240]:', 13, 10, 0
msg_ru_header_248:        db '[RUNNING] [KERNEL] payload_offset=[0x0248]:', 13, 10, 0
msg_ru_header_24c:        db '[RUNNING] [KERNEL] payload_length=[0x024c]:', 13, 10, 0
msg_ru_header_250:        db '[RUNNING] [KERNEL] setup_data=[0x0250]:', 13, 10, 0
msg_ru_header_258:        db '[RUNNING] [KERNEL] pref_address=[0x0258]:', 13, 10, 0
msg_ru_header_260:        db '[RUNNING] [KERNEL] init_size=[0x0260]:', 13, 10, 0
msg_ru_header_264:        db '[RUNNING] [KERNEL] handover_offset=[0x0264]:', 13, 10, 0
msg_ru_header_268:        db '[RUNNING] [KERNEL] kernel_info_offset=[0x0268]:', 13, 10, 0
