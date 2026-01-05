#![no_std]
#![no_main]

use core::panic::PanicInfo;
use core::arch::asm;


// COM1
const COM1: u16 = 0x3F8;

// Función para escribir un byte al puerto
#[inline]
unsafe fn outb(port: u16, val: u8) {
    asm!(
        "out dx, al",
        in("dx") port,
        in("al") val,
        options(nomem, nostack, preserves_flags)
    );
}

// Función para leer un byte del puerto
#[inline]
unsafe fn inb(port: u16) -> u8 {
    let ret: u8;
    asm!(
        "in al, dx",
        in("dx") port,
        out("al") ret,
        options(nomem, nostack, preserves_flags)
    );
    ret
}

// Inicializar COM1
unsafe fn init_serial() {
    outb(COM1 + 1, 0x00);  // Desactivar interrupciones
    outb(COM1 + 3, 0x80);  // Activar DLAB (divisor de baud rate)
    outb(COM1 + 0, 0x03);  // Divisor a 3 (byte bajo), 38400 baudios.
    outb(COM1 + 1, 0x00);  // Byte alto a 0
    outb(COM1 + 3, 0x03);  // 8 bits, N (no parity), 1 (1 bit de stop)
    // Poner FIFO, y vaciarlo con umbrales de 14 bytes
    outb(COM1 + 2, 0xC7);
    outb(COM1 + 4, 0x0B);  // IRQs activas, Modo RTS/DSR
}

// Verificar si el puerto está listo para transmitir
unsafe fn is_transmit_empty() -> bool {
    (inb(COM1 + 5) & 0x20) != 0
}

// Escribir un carácter en COM1
unsafe fn write_serial(c: u8) {
    while !is_transmit_empty() {}
    outb(COM1, c);
}

// Escribir una cadena
unsafe fn write_string_serial(s: &str) {
    for byte in s.bytes() {
        write_serial(byte);
    }
}

#[no_mangle]
#[link_section = ".text.entry"]
pub extern "C" fn kernel_entry() -> ! {
    unsafe {
        // Inicializar COM1
        init_serial();

        // Enviar mensaje de inicio
        write_string_serial("\r\n");
        write_string_serial("=========================================\r\n");
        write_string_serial("[KERNEL] Estamos dentro del RUST kernel!\r\n");
        write_string_serial("[KERNEL] Modo largo funcionando!\r\n");
        write_string_serial("=========================================\r\n");
        write_string_serial("\r\n");

        // Bucle infinito
        asm!(
            "cli",
            "2:",
            "hlt",
            "jmp 2b",
            options(noreturn)
        );
    }
}

// Panic handler (requisito) en no_std
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {
        unsafe {
            asm!("hlt", options(nomem, nostack, preserves_flags));
        }
    }
}
