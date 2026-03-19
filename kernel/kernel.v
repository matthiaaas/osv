@[has_globals]
module main

import riscv
import devices { Uart }
import proc { Process, Scheduler, Dispatcher }
import memory { FrameAllocator, Pagetable, MemoryRegion, PhysAddr }

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
	// file_table [64]File
}

pub fn Kernel.boot() {
	kernel.frame_allocator.init()

	kernel.pagetable = Pagetable.new() or {
		panic("Failed to create kernel pagetable")
	}
	kernel.map_kernel()

	init_process := Process.new(1) or {
		panic("Failed to create init process")
	}
	kernel.scheduler.enqueue(init_process)

	second_process := Process.new(2) or {
		panic("Failed to create second process")
	}
	kernel.scheduler.enqueue(second_process)

	for i in 0 .. 2 {
		process := &kernel.scheduler.processes[i]
		if process.pid == 1 {
			kernel.uart0.puts("pid: 1\n")
		} else if process.pid == 2 {
			kernel.uart0.puts("pid: 2\n")
		}
	}
}

pub fn (k &Kernel) map_kernel() {
	for region in kernel_regions {
		k.pagetable.map_region(region.virt_addr, region.size, region.phys_addr, region.perms)
	}
}

pub fn (mut k Kernel) run() {
	for {
		// TODO: disable interrerupts

		mut next_process := k.scheduler.pick_next() or {
			// TODO: enable interrupts & wait for interrupt: wfi
			continue
		}

		k.dispatcher.switch_to(mut next_process)

		// TODO: enable interrupts
	}
}

@[export: "kalloc_pages"]
pub fn kalloc_pages(page_count usize) voidptr {
    phys := kernel.frame_allocator.allocate_contiguous(page_count) or {
        return voidptr(0)
    }
    return voidptr(phys)
}

@[export: "kfree_pages"]
pub fn kfree_pages(base voidptr, page_count usize) {
	if base == 0 || page_count == 0 {
		return
	}

	for i in usize(0) .. page_count {
		phys := PhysAddr(usize(base) + i * riscv.page_size)
		kernel.frame_allocator.deallocate(phys)
	}
}
