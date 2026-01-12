module riscv

pub fn switch_sp(new_sp voidptr) {
	asm rv32 {
		mv sp, a0
		ret
	}
}

pub fn r_mcause() u32 {
	mut mcause := u32(0)
	asm rv32 {
		csrr a, mcause
		; =r (mcause) as a
	}
	return mcause
}

pub fn w_satp(satp u32) {
	asm rv32 {
		csrw satp, a0
		ret
	}
}

pub fn mret() {
	asm rv32 {
		mret
	}
}
