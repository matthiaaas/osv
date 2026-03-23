module loader

import memory { Pagetable, VirtAddr }
import riscv

pub struct LoadedProgram {
pub:
	entry     VirtAddr
	stack_top VirtAddr
}

pub interface ProgramLoader {
	load(mut pagetable Pagetable) !LoadedProgram
}

@[noinit]
pub struct BuiltinStubLoader implements ProgramLoader {
}

pub fn BuiltinStubLoader.new() BuiltinStubLoader {
	return BuiltinStubLoader{}
}

pub fn (_l BuiltinStubLoader) load(mut pagetable Pagetable) !LoadedProgram {
	code_frame := kernel.frame_allocator.allocate() or {
		return error('Failed to allocate code frame')
	}
	code_virt_addr := VirtAddr(0x1000)
	pagetable.map_region(code_virt_addr, riscv.page_size, code_frame, memory.pte_r | memory.pte_x | memory.pte_u)!

	stack_frame := kernel.frame_allocator.allocate() or {
		return error('Failed to allocate stack frame')
	}
	stack_virt_addr := VirtAddr(0x2000)
	pagetable.map_region(stack_virt_addr, riscv.page_size, stack_frame, memory.pte_r | memory.pte_w | memory.pte_u)!
	stack_top := u32(stack_virt_addr) + riscv.page_size

	unsafe {
		code := &u32(voidptr(code_frame))
		code[0] = 0x00000493 // li s1, 0          (Initialize sum in s1 to 0)
		code[1] = 0x00a00913 // li s2, 10         (Initialize loop counter in s2 to 10)
		code[2] = 0x0ac00893 // li a7, 172        (Set up a7 for sys_getpid)

		// LOOP START:
		code[3] = 0x00000073 // ecall             (Call sys_getpid)
		code[4] = 0x00a484b3 // add s1, s1, a0    (Accumulate returned PID into s1)
		code[5] = 0xfff90913 // addi s2, s2, -1   (Decrement the loop counter)
		code[6] = 0xfe091ae3 // bnez s2, .-12     (If s2 != 0, branch back 12 bytes to code[3])

		// EXIT:
		code[7] = 0x00048513 // mv a0, s1         (Move our sum from s1 into a0 for exit status)
		code[8] = 0x05d00893 // li a7, 93         (Set up a7 for sys_exit)
		code[9] = 0x00000073 // ecall             (Call exit)
	}
	return LoadedProgram{
		entry:     code_virt_addr
		stack_top: VirtAddr(stack_top)
	}
}
