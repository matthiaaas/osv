module memory

pub struct MemoryRegion {
pub:
	virt_addr VirtAddr
	phys_addr PhysAddr
	size      u32
	perms     u32
}
