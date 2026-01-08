module main

import memory

#include "symbols.h"

@[export: "kmain"]
fn kmain() {
	Uart.puts("Hello, World\n")

	kmem.init()

	mut i := u16(0)
	mut overflows := u32(0)
	for {
		i++

		if i == 0 {
			overflows++
			Uart.puts("Overflowed.\n")
		}
	}
}

fn main() {
	kmain()
}
