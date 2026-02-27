module memory

import riscv

fn C.__kernel_end()

struct FreePage {
mut:
	next &FreePage
}

@[noinit]
pub struct PageAllocator {
mut:
	free_list &FreePage
}

pub fn (mut allocator PageAllocator) init() {
	kernel_end := riscv.pgroundup(u32(voidptr(C.__kernel_end)))
	for page_addr := kernel_end; page_addr < riscv.phystop; page_addr += riscv.page_size {
		allocator.deallocate(voidptr(page_addr))
	}
}

pub fn (mut allocator PageAllocator) allocate() ?voidptr {
	if allocator.free_list == unsafe { nil } {
		return none
	}
	page := allocator.free_list
	allocator.free_list = page.next
	memset(page, 0, riscv.page_size)
	return voidptr(page)
}

pub fn (mut allocator PageAllocator) deallocate(phys_addr voidptr) {
	mut page := unsafe { &FreePage(phys_addr) }
	page.next = allocator.free_list
	allocator.free_list = page
}
