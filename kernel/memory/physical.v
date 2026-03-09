module memory

import riscv

fn C.__kernel_end()

struct FreeFrame {
mut:
	next &FreeFrame
}

@[noinit]
pub struct FrameAllocator {
mut:
	free_frames &FreeFrame
}

pub fn (mut allocator FrameAllocator) init() {
	kernel_end := PhysAddr(u32(voidptr(C.__kernel_end))).page_up()
	for page_addr := kernel_end; page_addr < riscv.phystop; page_addr += riscv.page_size {
		allocator.deallocate(page_addr)
	}
}

pub fn (mut allocator FrameAllocator) allocate() ?PhysAddr {
	if allocator.free_frames == unsafe { nil } {
		return none
	}
	frame := allocator.free_frames
	allocator.free_frames = frame.next
	memset(frame, 0, riscv.page_size)
	return PhysAddr(voidptr(frame))
}

pub fn (mut allocator FrameAllocator) deallocate(phys_addr PhysAddr) {
	mut frame := unsafe { &FreeFrame(voidptr(phys_addr)) }
	frame.next = allocator.free_frames
	allocator.free_frames = frame
}
