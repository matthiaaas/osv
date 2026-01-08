module riscv

pub fn mret() {
	asm rv32 {
		mret
	}
}
