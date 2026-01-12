module main

import memory
import riscv

#include "symbols.h"

const kstack_size = 4096

@[export: "kmain"]
fn kmain() {
	Uart.puts("Hello, World\n")

	kmem.init()

	mut kernel_stack_top := &u32(0)
	{
		page := kmem.alloc()
		kernel_stack_top = &u32(u32(page) + kstack_size)
	}
	riscv.switch_sp(voidptr(kernel_stack_top))

	for {}
}

fn main() {
	kmain()
}
