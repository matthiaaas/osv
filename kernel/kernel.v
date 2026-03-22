@[has_globals]
module main

import riscv
import devices { Uart }
import proc { Dispatcher, Process, Scheduler }
import memory { FrameAllocator, Pagetable, PhysAddr }
import loader { BuiltinStubLoader }

__global (
	kernel Kernel
)

pub struct Kernel {
pub mut:
	uart0           Uart
	frame_allocator FrameAllocator
	pagetable       Pagetable
	scheduler       Scheduler
	dispatcher      Dispatcher
	// file_table [64]File
}

pub fn Kernel.boot() {
	kernel.frame_allocator.init()

	stub_loader := BuiltinStubLoader.new()
	init_process := Process.bootstrap(1, stub_loader) or { panic('Failed to spawn init process') }
	kernel.scheduler.enqueue(init_process)

	second_loader := BuiltinStubLoader.new()
	second_process := Process.bootstrap(2, second_loader) or {
		panic('Failed to spawn second process')
	}
	kernel.scheduler.enqueue(second_process)
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

@[export: 'kalloc_pages']
pub fn kalloc_pages(page_count usize) voidptr {
	phys := kernel.frame_allocator.allocate_contiguous(page_count) or { return unsafe { nil } }
	return voidptr(phys)
}

@[export: 'kfree_pages']
pub fn kfree_pages(base voidptr, page_count usize) {
	if base == 0 || page_count == 0 {
		return
	}

	for i in usize(0) .. page_count {
		phys := PhysAddr(usize(base) + i * riscv.page_size)
		kernel.frame_allocator.deallocate(phys)
	}
}
