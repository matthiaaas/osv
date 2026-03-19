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

			for i in 0 .. 2 {
				process := &kernel.scheduler.processes[i]
				if process.pid == 1 {
					kernel.uart0.puts("pid: 1\n")
				} else if process.pid == 2 {
					kernel.uart0.puts("pid: 2\n")
				}
			}

			if mut curr_process := kernel.scheduler.current() {
				if curr_process.state == .running {
					curr_process.state = .ready
				}
			} else {
				trapframe.epc += 4 // fallback for now
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
			kernel.uart0.puts("Unknown Exception\n")
		}
	}
}
