@[has_globals]
module main

import riscv
import devices { Uart }
import proc { Process, Scheduler, Dispatcher }
import memory { FrameAllocator, Pagetable, MemoryRegion }

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
	uart0 Uart
	frame_allocator FrameAllocator
	pagetable Pagetable
	scheduler Scheduler
	dispatcher Dispatcher
}

pub fn Kernel.boot() {
	kernel.frame_allocator.init()

	kernel.pagetable = Pagetable.new() or {
		panic("Failed to create kernel pagetable")
	}

	kernel.map_kernel()

	kernel.scheduler = Scheduler{}
	kernel.dispatcher = Dispatcher{}

	init_process := Process.new(1) or {
		panic("Failed to create init process")
	}
	kernel.scheduler.enqueue(init_process)
}

pub fn (k Kernel) map_kernel() {
	for region in kernel_regions {
		k.pagetable.map_region(region.virt_addr, region.size, region.phys_addr, region.perms)
	}
}

pub fn (mut k Kernel) run() {
	mut last_pid := u32(0)

	for {
		// TODO: disable interrerupts

		next_process := k.scheduler.pick_next(last_pid) or {
			// TODO: enable interrupts & wait for interrupt: wfi
			continue
		}

		last_pid = next_process.pid
		k.dispatcher.run(next_process)

		// TODO: enable interrupts
	}
}
