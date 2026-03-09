module main

import riscv
import proc { TrapFrame }

@[export: "trap_handler"]
fn trap_handler(mut trapframe TrapFrame) {
	mcause := riscv.r_mcause()

	match mcause {
		2 {
			kernel.uart0.puts("Illegal Instruction\n")
			trapframe.epc += 4
		}
		8 {
			kernel.uart0.puts("Environment Call (U)\n")
			trapframe.epc += 4
		}
		3 {
			kernel.uart0.puts("Breakpoint\n")
			trapframe.epc += 4
		}
		else {
			kernel.uart0.puts("Unknown Exception\n")
		}
	}
}
