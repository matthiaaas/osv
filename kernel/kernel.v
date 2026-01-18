module main

import memory
import riscv

#include "symbols.h"

const kstack_size = 4096

fn map_kernel(pagetable memory.Pagetable) {
	pagetable.map_pages(0x8000_0000, 1024 * 1024, 0x8000_0000, memory.pte_r | memory.pte_w | memory.pte_x)
	pagetable.map_pages(0x1000_0000, 4096, 0x1000_0000, memory.pte_r | memory.pte_w)
}

@[export: "kmain"]
fn kmain() {
	Uart.puts("Hello, World\n")

	kmem.init()

	kernel_pagetable = memory.Pagetable.new()
	memset(voidptr(kernel_pagetable), 0, riscv.page_size)
	map_kernel(kernel_pagetable)
	riscv.w_satp(1 << 31 | kernel_pagetable.to_ppn())

	Uart.puts("Switched to kernel pagetable\n")

	stack_page := kmem.alloc()
	kernel_stack_top := voidptr(u32(stack_page) + kstack_size - 16)
	riscv.w_mscratch(u32(kernel_stack_top))
	riscv.call_with_stack(kernel_stack_top, kernel_main)
}

fn kernel_main() {
	Uart.puts("Running on kernel stack\n")

	mut proc0 := Process.new(1) or {
		Uart.puts("Process alloc failed\n")
		return
	}
	Uart.puts("proc0 allocated\n")

	user_code := kmem.alloc()
	if user_code == voidptr(0) {
		Uart.puts("user_code alloc failed\n")
		return
	}
	user_stack := kmem.alloc()
	if user_stack == voidptr(0) {
		Uart.puts("user_stack alloc failed\n")
		return
	}

	unsafe {
		code := &u32(user_code)
		code[0] = 0x00000513 // li a0, 0
		code[1] = 0x00000073 // ecall
		code[2] = 0x0000006f // j .
	}

	user_code_va := u32(0x0000_0000)
	user_stack_va := u32(0x0000_1000)

	proc0.pagetable = memory.Pagetable.new()
	memset(voidptr(proc0.pagetable), 0, riscv.page_size)
	map_kernel(proc0.pagetable)
	proc0.pagetable.map_pages(user_code_va, riscv.page_size, u32(user_code), memory.pte_r | memory.pte_x | memory.pte_u)
	proc0.pagetable.map_pages(user_stack_va, riscv.page_size, u32(user_stack), memory.pte_r | memory.pte_w | memory.pte_u)

	proc0.trapframe.epc = user_code_va
	proc0.trapframe.sp = user_stack_va + riscv.page_size

	Uart.puts("Entering user mode\n")
	riscv.w_mscratch(u32(proc0.kernel_sp))
	riscv.w_satp(1 << 31 | proc0.pagetable.to_ppn())
	trap_return(mut proc0.trapframe)

	mut i := 0

	for {
		i += 1
		if i % 1_000_000 == 0 {
			Uart.puts("Cycle\n")
		}
	}
}

fn main() {
	kmain()
}
