module main

import riscv

pub struct TrapFrame {
mut:
	ra u32
	sp u32
	gp u32
	tp u32

	t0 u32
	t1 u32
	t2 u32

	s0 u32
	s1 u32

	a0 u32
	a1 u32
	a2 u32
	a3 u32
	a4 u32
	a5 u32
	a6 u32
	a7 u32

	s2 u32
	s3 u32
	s4 u32
	s5 u32
	s6 u32
	s7 u32
	s8 u32
	s9 u32
	s10 u32
	s11 u32

	t3 u32
	t4 u32
	t5 u32
	t6 u32

	epc u32
}

@[export: "trap_handler"]
fn trap_handler(mut trapframe TrapFrame) {
	mcause := riscv.r_mcause()

	match mcause {
		2 {
			Uart.puts("Illegal Instruction\n")
			trapframe.epc += 4
		}
		8 {
			Uart.puts("Environment Call (U)\n")
			trapframe.epc += 4
		}
		3 {
			Uart.puts("Breakpoint\n")
			trapframe.epc += 4
		}
		else {
			Uart.puts("Unknown Exception\n")
		}
	}
}

pub fn trap_return(mut trapframe TrapFrame) {
	mut mstatus := riscv.r_mstatus()
	mstatus &= ~(u32(3) << 11)
	mstatus |= u32(1) << 7
	riscv.w_mstatus(mstatus)
	riscv.w_mepc(trapframe.epc)
	riscv.mret()
}
