module memory

pub type VirtAddr = u32

@[inline]
pub fn (virt_addr VirtAddr) vpn1() u32 {
	return (u32(virt_addr) >> 22) & 0x3ff
}

@[inline]
pub fn (virt_addr VirtAddr) vpn0() u32 {
	return (u32(virt_addr) >> 12) & 0x3ff
}

pub type PhysAddr = u32

@[inline]
fn (phys_addr PhysAddr) to_ppn() u32 {
	return (u32(phys_addr) >> 12) << 10
}

@[inline]
fn ppn_to_pa(ppn u32) u32 {
	return (ppn >> 10) << 12
}

