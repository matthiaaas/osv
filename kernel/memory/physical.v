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
	kernel_end := PhysAddr(usize(voidptr(C.__kernel_end))).page_up()
	for frame_addr := kernel_end; frame_addr < riscv.phystop; frame_addr += riscv.page_size {
		allocator.deallocate(frame_addr)
	}
}

pub fn (mut allocator FrameAllocator) allocate() ?PhysAddr {
	if allocator.free_frames == unsafe { nil } {
		return none
	}
	frame := allocator.free_frames
	allocator.free_frames = frame.next
	memset(frame, 0, riscv.page_size)
	return PhysAddr(usize(voidptr(frame)))
}

pub fn (mut allocator FrameAllocator) allocate_contiguous(page_count usize) ?PhysAddr {
	if page_count == 0 {
		return none
	}

	first := allocator.allocate()?
	mut lowest := first
	mut prev := first

	for i in 1 .. page_count {
        next := allocator.allocate()?

        if usize(next) + usize(riscv.page_size) != usize(prev) {
            panic("frame allocator fragmented: contiguous run required")
        }

        lowest = next
        prev = next
    }

    return lowest
}

pub fn (mut allocator FrameAllocator) deallocate(phys_addr PhysAddr) {
	mut frame := unsafe { &FreeFrame(voidptr(phys_addr)) }
	frame.next = allocator.free_frames
	allocator.free_frames = frame
}
