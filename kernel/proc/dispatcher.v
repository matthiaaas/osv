module proc

import riscv

pub struct Dispatcher {
}

pub fn (mut dispatcher Dispatcher) switch_to(mut process Process) {
	process.state = .running

	mut mstatus := riscv.r_mstatus()
    mstatus &= ~(u32(3) << 11)
    riscv.w_mstatus(mstatus)

	riscv.w_mepc(process.trapframe.epc)

	riscv.w_satp((1 << 31) | process.pagetable.to_ppn())

	riscv.w_mscratch(process.kernel_stack_top)

	riscv.trap_return(&process.trapframe, process.kernel_stack_top)
}
