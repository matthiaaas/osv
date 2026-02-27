module riscv

pub const dram_base = u32(0x8000_0000)
pub const dram_size = u32(1 * 1024 * 1024) // 1MB
pub const phystop = dram_base + dram_size // 1MB

pub const uart0_base = u32(0x1000_0000)
pub const uart_size = u32(0x1000)

pub const page_size = u32(4096)

@[inline]
pub fn pgrounddown(addr u32) u32 {
	return addr & ~(page_size - 1)
}

@[inline]
pub fn pgroundup(addr u32) u32 {
	return (addr + page_size - 1) & ~(page_size - 1)
}
