module riscv

@[inline]
pub fn call_with_stack(new_sp voidptr, func fn ()) {
	asm rv32 {
		mv sp, a
		jalr zero, b, 0
		; ; r (new_sp) as a
		  r (func) as b
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

pub fn r_mstatus() u32 {
	mut mstatus := u32(0)
	asm rv32 {
		csrr a, mstatus
		; =r (mstatus) as a
	}
	return mstatus
}

@[inline]
pub fn w_mstatus(val u32) {
	asm rv32 {
		csrw mstatus, a
		; ; r (val) as a
	}
}

@[inline]
pub fn w_mepc(val u32) {
	asm rv32 {
		csrw mepc, a
		; ; r (val) as a
	}
}

@[inline]
pub fn w_mtvec(val u32) {
	asm rv32 {
		csrw mtvec, a
		; ; r (val) as a
	}
}

@[inline]
pub fn w_mscratch(val u32) {
	asm rv32 {
		csrw mscratch, a
		; ; r (val) as a
	}
}

@[inline]
pub fn w_satp(satp u32) {
	asm rv32 {
		csrw satp, a
		; ; r (satp) as a
	}
}

@[inline]
pub fn mret() {
	asm rv32 {
		mret
	}
}
