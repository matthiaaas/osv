module riscv

pub const page_size = 4096

@[inline]
pub fn pgrounddown(addr u32) u32 {
	return addr & ~(page_size - 1)
}

@[inline]
pub fn pgroundup(addr u32) u32 {
	return (addr + page_size - 1) & ~(page_size - 1)
}
