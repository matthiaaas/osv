module loader

import memory { Pagetable, VirtAddr }
import riscv

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

		// --- 1. CLONE (FORK) ---
        code[0] = 0x01100513 // li a0, 17          (Flags: SIGCHLD = 17 for standard fork)
        code[1] = 0x00000593 // li a1, 0           (child_stack = 0 to copy parent stack)
        code[2] = 0x0dc00893 // li a7, 220         (sys_clone)
        code[3] = 0x00000073 // ecall

        // --- 2. GET PID ---
        code[4] = 0x0ac00893 // li a7, 172         (sys_getpid)
        code[5] = 0x00000073 // ecall              (PID is now stored in a0)

        // --- 3. EXIT ---
        // Note: a0 already holds the PID returned from sys_getpid, 
        // so we don't need to move it. It acts directly as the exit code.
        code[6] = 0x05d00893 // li a7, 93          (sys_exit)
        code[7] = 0x00000073 // ecall

		// // --- 1. SETUP STACK & STRING ---
		// code[0] = 0xfe010113 // addi sp, sp, -32   (Allocate 32 bytes on stack)
		// code[1] = 0x736572b7 // lui t0, 0x73657    (Upper 20 bits of "/tes")
		// code[2] = 0x42f28293 // addi t0, t0, 1071  (Lower 12 bits)
		// code[3] = 0x00512823 // sw t0, 16(sp)      (Store "/tes" at sp+16)
		// code[4] = 0x787432b7 // lui t0, 0x78743    (Upper 20 bits of "t.tx")
		// code[5] = 0xe7428293 // addi t0, t0, -396  (Lower 12 bits)
		// code[6] = 0x00512a23 // sw t0, 20(sp)      (Store "t.tx" at sp+20)
		// code[7] = 0x07400293 // li t0, 116         (Load "t\0\0\0")
		// code[8] = 0x00512c23 // sw t0, 24(sp)      (Store "t\0\0\0" at sp+24)

		// // --- 2. OPENAT (O_RDWR) ---
		// code[9] = 0x00000513 // li a0, 0           (Dummy dirfd = 0)
		// code[10] = 0x01010593 // addi a1, sp, 16    (Pointer to "/test.txt\0")
		// code[11] = 0x00200613 // li a2, 2           (Flags: O_RDWR = 2)
		// code[12] = 0x00000693 // li a3, 0           (Mode: 0)
		// code[13] = 0x03800893 // li a7, 56          (sys_openat)
		// code[14] = 0x00000073 // ecall

		// // --- 3. SAVE FD ---
		// code[15] = 0x00050493 // mv s1, a0          (Save fd into s1)

		// // --- 4. READ ---
		// code[16] = 0x00048513 // mv a0, s1          (a0 = fd)
		// code[17] = 0x00010593 // mv a1, sp          (a1 = read buffer at sp)
		// code[18] = 0x00d00613 // li a2, 13          (Count = 13 bytes)
		// code[19] = 0x03f00893 // li a7, 63          (sys_read)
		// code[20] = 0x00000073 // ecall

		// // --- 5. TOGGLE '!' AND '?' ---
		// code[21] = 0x00c10283 // lb t0, 12(sp)      (Load 13th byte)
		// code[22] = 0x01e2c293 // xori t0, t0, 30    (XOR with 30 / 0x1E to flip ! and ?)
		// code[23] = 0x00510623 // sb t0, 12(sp)      (Store modified byte back to buffer)

		// // --- 6. REWIND (LSEEK) ---
		// code[24] = 0x00048513 // mv a0, s1          (a0 = fd)
		// code[25] = 0x00000593 // li a1, 0           (Offset = 0)
		// code[26] = 0x00000613 // li a2, 0           (Whence = SEEK_SET = 0)
		// code[27] = 0x03e00893 // li a7, 62          (sys_lseek)
		// code[28] = 0x00000073 // ecall

		// // --- 7. WRITE TO FILE ---
		// code[29] = 0x00048513 // mv a0, s1          (a0 = fd)
		// code[30] = 0x00010593 // mv a1, sp          (Pointer to buffer)
		// code[31] = 0x00d00613 // li a2, 13          (Count = 13 bytes)
		// code[32] = 0x04000893 // li a7, 64          (sys_write)
		// code[33] = 0x00000073 // ecall

		// // --- 8. CLOSE ---
		// code[34] = 0x00048513 // mv a0, s1          (a0 = fd)
		// code[35] = 0x03900893 // li a7, 57          (sys_close)
		// code[36] = 0x00000073 // ecall

		// // --- 9. CLEANUP ---
		// code[37] = 0x02010113 // addi sp, sp, 32    (Restore stack pointer)

		// code := &u32(voidptr(code_frame))
		// code[0] = 0x00000493 // li s1, 0          (Initialize sum in s1 to 0)
		// code[1] = 0x00a00913 // li s2, 10         (Initialize loop counter in s2 to 10)
		// code[2] = 0x0ac00893 // li a7, 172        (Set up a7 for sys_getpid)

		// // LOOP START:
		// code[3] = 0x00000073 // ecall             (Call sys_getpid)
		// code[4] = 0x00a484b3 // add s1, s1, a0    (Accumulate returned PID into s1)
		// code[5] = 0xfff90913 // addi s2, s2, -1   (Decrement the loop counter)
		// code[6] = 0xfe091ae3 // bnez s2, .-12     (If s2 != 0, branch back 12 bytes to code[3])

		// // EXIT:
		// code[7] = 0x00048513 // mv a0, s1         (Move our sum from s1 into a0 for exit status)
		// code[8] = 0x05d00893 // li a7, 93         (Set up a7 for sys_exit)
		// code[9] = 0x00000073 // ecall             (Call exit)
	}
	return LoadedProgram{
		entry:     code_virt_addr
		stack_top: VirtAddr(stack_top)
	}
}
