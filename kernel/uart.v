module main

pub struct Uart {}

pub fn Uart.put(c u8) {
	unsafe {
		mut volatile uart0_base := &int(0x1000_0000)
		*uart0_base = int(c)
	}
}

pub fn Uart.puts(s string) {
	for c in s {
		Uart.put(c)
	}
}

pub fn Uart.puts_u32(n u32) {
	for i := 0; i < 4; i++ {
		byt := u8((n >> (i * 8)) & 0xFF)
		Uart.put(byt)
	}
}
