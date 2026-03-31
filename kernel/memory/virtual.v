module memory

import riscv

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

pub fn Pagetable.new() !Pagetable {
	frame := kernel.frame_allocator.allocate() or {
		return error('Failed to allocate pagetable frame')
	}
	return Pagetable(voidptr(frame))
}

@[inline]
pub fn (pagetable Pagetable) at(vpn u32) PagetableEntry {
	assert vpn < pagetable_size
	return PagetableEntry(unsafe { &u32(pagetable) + vpn })
}

@[inline]
pub fn (pagetable Pagetable) phys_addr() PhysAddr {
	return PhysAddr(usize(voidptr(pagetable)))
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

	subtable := Pagetable.new() or { return none }
	pte.point_to(subtable.phys_addr(), 0)

	return subtable.at(virt_addr.vpn0())
}

pub fn (pagetable Pagetable) map_region(virt_addr VirtAddr, size u32, phys_addr PhysAddr, perms u32) ! {
	mut curr_virt_addr := virt_addr.page_down()
	mut curr_phys_addr := phys_addr.page_down()
	end_virt_addr := VirtAddr(virt_addr + size - 1).page_down()

	for {
		pte := pagetable.walk(curr_virt_addr, true) or {
			return error('map_region walk failed at ${curr_virt_addr}')
		}

		if pte.is_valid() {
			return error('remap collision at ${curr_virt_addr}')
		}

		pte.point_to(curr_phys_addr, perms)

		if curr_virt_addr == end_virt_addr {
			break
		}

		curr_virt_addr += riscv.page_size
		curr_phys_addr += riscv.page_size
	}
}

@[inline]
pub fn (pagetable Pagetable) to_ppn() u32 {
	return (u32(voidptr(pagetable)) >> 12) & 0x003f_ffff
}

@[inline]
pub fn (pagetable Pagetable) raw_value() u32 {
	return u32(voidptr(pagetable))
}

pub fn (pagetable Pagetable) clone() !Pagetable {
	child := Pagetable.new()!

	for vpn1 in 0 .. int(pagetable_size) {
		parent_l1_pte := pagetable.at(u32(vpn1))
		if !parent_l1_pte.is_valid() {
			continue
		}

		parent_subtable := parent_l1_pte.as_pagetable()
		child_subtable := Pagetable.new()!
		child.at(u32(vpn1)).point_to(child_subtable.phys_addr(), 0)

		for vpn0 in 0 .. int(pagetable_size) {
			parent_l2_pte := parent_subtable.at(u32(vpn0))
			if !parent_l2_pte.is_valid() {
				continue
			}

			// Extract permission flags, excluding pte_v (point_to re-adds it)
			perms := parent_l2_pte.raw_value() & 0x3fe

			if parent_l2_pte.raw_value() & pte_u != 0 {
				src := parent_l2_pte.phys_addr()
				dst := kernel.frame_allocator.allocate() or {
					return error('pagetable clone: out of frames')
				}
				unsafe { C.memcpy(voidptr(dst), voidptr(src), riscv.page_size) }
				child_subtable.at(u32(vpn0)).point_to(dst, perms)
			} else {
				child_subtable.at(u32(vpn0)).point_to(parent_l2_pte.phys_addr(), perms)
			}
		}
	}

	return child
}

pub type PagetableEntry = &u32

@[inline]
pub fn (pte PagetableEntry) raw_value() u32 {
	return unsafe { *(&u32(pte)) }
}

@[inline]
fn (pte PagetableEntry) set(val u32) {
	unsafe {
		*(&u32(pte)) = val
	}
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
