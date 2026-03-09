module proc

import riscv
import memory { Pagetable, VirtAddr, PhysAddr }

pub enum ProcessState {
	unused
	ready
	running
	sleeping
	zombie
}

pub struct Process {
pub:
	pid u32
mut:
	state ProcessState
	pagetable Pagetable
	// context TrapFrame
	kernel_sp u32
	// file_descriptors []File
}

pub fn Process.new(pid u32) ?Process {
	pagetable := Pagetable.new()?

	user_code_frame := kernel.frame_allocator.allocate()?
	user_code_virt_addr := VirtAddr(0x1000)

	pagetable.map_region(
		user_code_virt_addr,
		riscv.page_size,
		user_code_frame,
		memory.pte_r | memory.pte_x | memory.pte_u
	)

	user_stack_frame := kernel.frame_allocator.allocate()?
	user_stack_virt_addr := VirtAddr(0x2000)
	pagetable.map_region(
		user_stack_virt_addr,
		riscv.page_size,
		user_stack_frame,
		memory.pte_r | memory.pte_w | memory.pte_u
	)

	unsafe {
		code := &u32(voidptr(user_code_frame))
        code[0] = 0x02a00513 // li a0, 42
        code[1] = 0x00000073 // ecall
        code[2] = 0xffdff06f // j .-4  (loop back to ecall)
    }

	return Process{
		pid: pid
		state: .ready
		pagetable: pagetable
	}
}

