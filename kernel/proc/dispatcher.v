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

    riscv.w_mscratch(u32(voidptr(&process.trapframe)))

    riscv.trap_return(&process.trapframe)
}
