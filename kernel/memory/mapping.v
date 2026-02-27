module memory

import riscv

pub fn init_kernel_mappings() ?Pagetable {
	pagetable := Pagetable.new()?

	regions := [
		MemoryRegion{
			virt_addr: riscv.dram_base
			phys_addr: riscv.dram_base
			size: riscv.dram_size
			perms: pte_r | pte_w | pte_x
		},
		MemoryRegion{
			virt_addr: riscv.uart0_base
			phys_addr: riscv.uart0_base
			size: riscv.uart_size
			perms: pte_r | pte_w
		}
	]

	for region in regions {
		pagetable.map_region(region.virt_addr, region.size, region.phys_addr, region.perms)
	}

	return pagetable
}
