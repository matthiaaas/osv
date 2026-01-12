@[has_globals]
module memory

fn C.__kernel_end()

__global (
	kmem Kmem
)

pub const pgsize = 4096
pub const phystop = 0x80000000 + 1 * 1024 * 1024 // 1MB

@[noinit]
struct Run {
mut:
	next &Run
}

@[noinit]
pub struct Kmem {
mut:
	free_list &Run
}

pub fn (mut self Kmem) init() {
	kernel_end := u32(voidptr(C.__kernel_end))

	for i := kernel_end; i < phystop; i += pgsize {
		self.kfree(voidptr(i))
	}
}

pub fn (mut self Kmem) alloc() voidptr {
	unsafe {
		if self.free_list == voidptr(0) {
			return voidptr(0)
		}
		r := self.free_list
		memset(r, 0, pgsize)
		self.free_list = r.next
		return voidptr(r)
	}
}

pub fn (mut self Kmem) kfree(pa voidptr) {
	unsafe {
		r := &Run(voidptr(pa))
		r.next = self.free_list
		self.free_list = r
	}
}
