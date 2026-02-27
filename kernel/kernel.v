@[has_globals]
module main

import riscv
import proc { Scheduler, Dispatcher }
import memory { PageAllocator, Pagetable, MemoryRegion }

__global (
	kernel Kernel
)

const kernel_regions := [
		MemoryRegion{
			virt_addr: riscv.dram_base
			phys_addr: riscv.dram_base
			size: riscv.dram_size
			perms: memory.pte_r | memory.pte_w | memory.pte_x
		},
		MemoryRegion{
			virt_addr: riscv.uart0_base
			phys_addr: riscv.uart0_base
			size: riscv.uart_size
			perms: memory.pte_r | memory.pte_w
		}
	]

pub struct Kernel {
pub mut:
	page_allocator PageAllocator
	pagetable Pagetable
	scheduler Scheduler
	dispatcher Dispatcher
}

pub fn Kernel.boot() {
	kernel.page_allocator.init()

	kernel.pagetable = Pagetable.new() or {
		Uart.puts("Failed to create kernel pagetable\n")
		return
	}

	kernel.scheduler = Scheduler{}
	kernel.dispatcher = Dispatcher{}
}

pub fn (k Kernel) map_kernel() {
	for region in kernel_regions {
		k.pagetable.map_region(region.virt_addr, region.size, region.phys_addr, region.perms)
	}
}

// pub fn (kernel Kernel) boot() {

// }

pub fn (mut k Kernel) run_scheduler() {
	for {
		// next := kernel.scheduler.pick_next()

		// kernel.dispatcher.run(&next)
	}
}
