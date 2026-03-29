@[has_globals]
module main

import riscv
import devices { Disk, Uart }
import proc { Dispatcher, Process, Scheduler }
import memory { FrameAllocator, Pagetable, PhysAddr }
import loader { BuiltinStubLoader }
import vfs { VirtualFileSystem }
import fs { IndexedFileSystem }

__global (
	kernel Kernel
)

pub struct Kernel {
pub mut:
	uart0           Uart
	disk0           Disk
	frame_allocator FrameAllocator
	pagetable       Pagetable
	scheduler       Scheduler
	dispatcher      Dispatcher
	vfs             VirtualFileSystem
	// global_file_table GlobalFileTable
}

pub fn Kernel.boot() {
	kernel.frame_allocator.init()

	root_fs := IndexedFileSystem.load(kernel.disk0) or {
		kernel.uart0.puts('Failed to load root filesystem. Formatting...\n')
		IndexedFileSystem.format(kernel.disk0) or { panic('Failed to format root filesystem') }
	}
	kernel.vfs.mount('/', root_fs) or { panic('Failed to mount root filesystem') }

	mut root_vnode := kernel.vfs.resolve('/') or { panic('Failed to resolve root') }
	kernel.uart0.puts('Resolved root: ${root_vnode.is_directory()}\n')

	root_vnode.create("test.txt", false) or { panic('Failed to create test.txt') }

	mut test_vnode := root_vnode.lookup("test.txt") or { panic('Failed to lookup test.txt') }
	kernel.uart0.puts('Resolved test.txt: ${test_vnode.is_directory()}\n')

	aaaaa := "Hello, world!\n".bytes()
	test_vnode.write_at(unsafe { &aaaaa[0]}, 13, 0) or { panic('Failed to write to test.txt') }

	buf := [13]u8{}
	test_vnode.read_at(unsafe { &buf[0]}, 13, 0) or { panic('Failed to read from test.txt') }
	contents := unsafe { tos_clone(&buf[0]) }
	kernel.uart0.puts('Read from test.txt: ${contents}\n')

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
