module main

import riscv
import proc { TrapFrame }
import syscall { handle_syscall }

@[export: "trap_handler"]
fn trap_handler(mut trapframe TrapFrame) {
	mcause := riscv.r_mcause()

	match mcause {
		2 {
			kernel.uart0.puts("Illegal Instruction\n")
			trapframe.epc += 4
		}
		8 {
			handle_syscall(trapframe.a7)

			mut curr_process := kernel.scheduler.current() or {
				panic("No current process in ecall trap")
			}
			curr_process.trapframe = trapframe
			curr_process.trapframe.epc += 4

			if curr_process.state == .running {
				curr_process.state = .ready
			}

			mut next_process := kernel.scheduler.pick_next() or {
				panic("No ready/runnable process after trap")
			}
			kernel.dispatcher.switch_to(mut next_process)
		}
		3 {
			kernel.uart0.puts("Breakpoint\n")
			trapframe.epc += 4
		}
		else {
			panic("Unhandled trap cause=${mcause}")
		}
	}
}
