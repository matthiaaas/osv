module memory

import riscv
import devices

const kernel_regions = [
	MemoryRegion{
		virt_addr: riscv.dram_base
		phys_addr: riscv.dram_base
		size:      riscv.dram_size
		perms:     pte_r | pte_w | pte_x
	},
	MemoryRegion{
		virt_addr: riscv.uart0_base
		phys_addr: riscv.uart0_base
		size:      riscv.uart0_mmio_size
		perms:     pte_r | pte_w
	},
	MemoryRegion{
		virt_addr: devices.disk0_base
		phys_addr: devices.disk0_base
		size:      devices.disk0_mmio_size
		perms:     pte_r | pte_w
	},
]

pub fn map_kernel_regions(pagetable Pagetable) ! {
	for region in kernel_regions {
		pagetable.map_region(region.virt_addr, region.size, region.phys_addr, region.perms)!
	}
}
