module loader

import memory { VirtAddr, Pagetable }
import riscv

pub struct LoadedProgram {
pub:
	entry VirtAddr
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
		return error("Failed to allocate code frame")
	}
	code_virt_addr := VirtAddr(0x1000)
	pagetable.map_region(
		code_virt_addr,
		riscv.page_size,
		code_frame,
		memory.pte_r | memory.pte_x | memory.pte_u
	)!

	stack_frame := kernel.frame_allocator.allocate() or {
		return error("Failed to allocate stack frame")
	}
	stack_virt_addr := VirtAddr(0x2000)
	pagetable.map_region(
		stack_virt_addr,
		riscv.page_size,
		stack_frame,
		memory.pte_r | memory.pte_w | memory.pte_u
	)!
	stack_top := u32(stack_frame) + riscv.page_size

	unsafe {
		code := &u32(voidptr(code_frame))
		code[0] = 0x02a00513 // li a0, 42
		code[1] = 0x00000073 // ecall
		code[2] = 0xffdff06f // j .-4  (loop back to ecall)
	}

	return LoadedProgram{
		entry: code_virt_addr
		stack_top: VirtAddr(stack_top)
	}
}
