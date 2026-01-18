module memory

import riscv

__global (
	kernel_pagetable Pagetable
)

pub const pte_v = u32(1 << 0)
pub const pte_r = u32(1 << 1)
pub const pte_w = u32(1 << 2)
pub const pte_x = u32(1 << 3)
pub const pte_u = u32(1 << 4)
pub const pte_g = u32(1 << 5)
pub const pte_a = u32(1 << 6)
pub const pte_d = u32(1 << 7)

pub type Pagetable = &u32
pub type PagetableEntry = &u32
pub type VirtAddr = u32

pub fn Pagetable.new() Pagetable {
	return Pagetable(kmem.alloc())
}

pub fn (pagetable Pagetable) walk(virt_addr VirtAddr, alloc bool) ?PagetableEntry {
	mut pt := &u32(pagetable)
	pte := PagetableEntry(unsafe { &pt[virt_addr.vpn1()] })

	if pte.is_valid() {
		pt = &u32(unsafe { voidptr(ppn_to_pa(pte.value())) })
	} else {
		if !alloc {
			return none
		}

		new_page := kmem.alloc()
		if new_page == voidptr(0) {
			return none
		}
		memset(new_page, 0, riscv.page_size)

		pte.set(pa_to_ppn(u32(new_page)) | pte_v)

		pt = &u32(new_page)
	}

	return PagetableEntry(unsafe { &pt[virt_addr.vpn0()] })
}

pub fn (pagetable Pagetable) map_pages(virt_addr u32, size u32, phys_addr u32, perm u32) {
	mut a := riscv.pgrounddown(virt_addr)
	mut pa := riscv.pgrounddown(phys_addr)
	last := riscv.pgrounddown(virt_addr + size - 1)

	for {
		pte := pagetable.walk(a, true) or {
			panic("map_pages walk failed")
		}

		if pte.is_valid() {
			panic("remap")
		}

		pte.set(pa_to_ppn(pa) | u32(perm) | pte_v)

		if a == last {
			break
		}

		a += riscv.page_size
		pa += riscv.page_size
	}
}

@[inline]
pub fn (pagetable Pagetable) to_ppn() u32 {
	return (u32(voidptr(pagetable)) >> 12) & 0x003f_ffff
}

@[inline]
pub fn (pte PagetableEntry) value() u32 {
	return unsafe { *(&u32(pte)) }
}

@[inline]
pub fn (pte PagetableEntry) set(val u32) {
	unsafe {
		*(&u32(pte)) = val
	}
}

@[inline]
pub fn (pte PagetableEntry) is_valid() bool {
	return (pte.value() & pte_v) != 0
}

@[inline]
pub fn (virt_addr VirtAddr) vpn1() u32 {
	return (u32(virt_addr) >> 22) & 0x3ff
}

@[inline]
pub fn (virt_addr VirtAddr) vpn0() u32 {
	return (u32(virt_addr) >> 12) & 0x3ff
}

@[inline]
fn pa_to_ppn(pa u32) u32 {
	return (pa >> 12) << 10
}

@[inline]
fn ppn_to_pa(ppn u32) u32 {
	return (ppn >> 10) << 12
}
