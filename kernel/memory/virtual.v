module memory

import riscv

__global (
	kernel_pagetable Pagetable
)

pub const pagetable_size = u32(1024)

pub const pte_v = u32(1 << 0)
pub const pte_r = u32(1 << 1)
pub const pte_w = u32(1 << 2)
pub const pte_x = u32(1 << 3)
pub const pte_u = u32(1 << 4)
pub const pte_g = u32(1 << 5)
pub const pte_a = u32(1 << 6)
pub const pte_d = u32(1 << 7)

pub type Pagetable = &u32

pub fn Pagetable.new() ?Pagetable {
	page := kernel.page_allocator.allocate()?
	return Pagetable(page)
}

@[inline]
pub fn (pagetable Pagetable) at(vpn u32) PagetableEntry {
	assert vpn < pagetable_size
	return PagetableEntry(unsafe { &u32(pagetable) + vpn })
}

@[inline]
pub fn (pagetable Pagetable) phys_addr() PhysAddr {
	return PhysAddr(voidptr(pagetable))
}

pub fn (pagetable Pagetable) walk(virt_addr VirtAddr, alloc bool) ?PagetableEntry {
	pte := pagetable.at(virt_addr.vpn1())

	if pte.is_valid() {
        subtable := pte.as_pagetable()
        return subtable.at(virt_addr.vpn0())
    }

	if !alloc {
		return none
	}

	subtable := Pagetable.new()?
	pte.point_to(subtable.phys_addr(), 0)

	return subtable.at(virt_addr.vpn0())
}

pub fn (pagetable Pagetable) map_region(virt_addr VirtAddr, size u32, phys_addr PhysAddr, perms u32) {
	mut curr_virt_addr := riscv.pgrounddown(virt_addr)
	mut curr_phys_addr := riscv.pgrounddown(phys_addr)
	end_virt_addr := riscv.pgrounddown(virt_addr + size - 1)

	for {
		pte := pagetable.walk(curr_virt_addr, true) or {
			panic("map_region walk failed")
		}

		if pte.is_valid() {
			panic("remap collision")
		}

		pte.point_to(curr_phys_addr, perms)

		if curr_virt_addr == end_virt_addr {
			break
		}

		curr_virt_addr += riscv.page_size
		curr_phys_addr += riscv.page_size
	}
}

pub fn (pagetable Pagetable) activate() {

}

@[inline]
pub fn (pagetable Pagetable) to_ppn() u32 {
	return (u32(voidptr(pagetable)) >> 12) & 0x003f_ffff
}

@[inline]
pub fn (pagetable Pagetable) raw_value() u32 {
	return u32(voidptr(pagetable))
}

pub type PagetableEntry = &u32

@[inline]
pub fn (pte PagetableEntry) raw_value() u32 {
	return unsafe { *(&u32(pte)) }
}


@[inline]
fn (pte PagetableEntry) set(val u32) {
	unsafe { *(&u32(pte)) = val }
}

@[inline]
pub fn (pte PagetableEntry) point_to(phys_addr PhysAddr, flags u32) {
	pte.set(phys_addr.to_ppn() | flags | pte_v)
}

@[inline]
pub fn (pte PagetableEntry) is_valid() bool {
	return (pte.raw_value() & pte_v) != 0
}

@[inline]
pub fn (pte PagetableEntry) phys_addr() PhysAddr {
	return PhysAddr(voidptr((pte.raw_value() >> 10) << 12))
}

@[inline]
pub fn (pte PagetableEntry) as_pagetable() Pagetable {
	return Pagetable(voidptr(pte.phys_addr()))
}

pub struct MemoryRegion {
pub:
	virt_addr VirtAddr
	phys_addr PhysAddr
	size u32
	perms u32
}
