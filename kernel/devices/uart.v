module devices

import riscv

pub struct Uart {}

pub fn (uart Uart) put(c u8) {
	unsafe {
		mut volatile uart0_base := &int(riscv.uart0_base)
		*uart0_base = int(c)
	}
}

pub fn (uart Uart) puts(s string) {
	for c in s {
		uart.put(c)
	}
}
