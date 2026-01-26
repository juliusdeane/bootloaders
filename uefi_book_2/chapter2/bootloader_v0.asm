;*****************************************************************************
; Fuente para FASM.
; - fasm bootloader_v0.asm
; - este programa no hace nada, retorna inmediatamente (sale).
;*****************************************************************************
format pe64 efi  ; Formato de aplicación EFI de 64 bits
entry main       ; Entry point.

section '.text' executable readable

main:
  ret
