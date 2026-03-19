module memory

import riscv

pub type VirtAddr = usize

@[inline]
pub fn (virt_addr VirtAddr) page_down() VirtAddr {
	return VirtAddr(riscv.pgrounddown(u32(virt_addr)))
}

@[inline]
pub fn (virt_addr VirtAddr) page_up() VirtAddr {
	return VirtAddr(riscv.pgroundup(u32(virt_addr)))
}

@[inline]
pub fn (virt_addr VirtAddr) vpn1() u32 {
	return (u32(virt_addr) >> 22) & 0x3ff
}

@[inline]
pub fn (virt_addr VirtAddr) vpn0() u32 {
	return (u32(virt_addr) >> 12) & 0x3ff
}

pub type PhysAddr = usize

@[inline]
pub fn (phys_addr PhysAddr) page_down() PhysAddr {
	return PhysAddr(riscv.pgrounddown(u32(phys_addr)))
}

@[inline]
pub fn (phys_addr PhysAddr) page_up() PhysAddr {
	return PhysAddr(riscv.pgroundup(u32(phys_addr)))
}

@[inline]
fn (phys_addr PhysAddr) to_ppn() u32 {
	return (u32(phys_addr) >> 12) << 10
}

@[inline]
fn ppn_to_pa(ppn u32) PhysAddr {
	return PhysAddr((ppn >> 10) << 12)
}

