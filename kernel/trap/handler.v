module trap

import riscv
import proc { TrapFrame }

@[export: 'trap_handler']
fn trap_handler(mut trapframe TrapFrame) {
	mcause := riscv.r_mcause()
	cause := TrapCause.from(mcause) or {
		panic('Unknown trap cause=${mcause}')
	}

	mut curr_process := kernel.scheduler.current() or {
		panic('No current process after trap')
	}
	curr_process.trapframe = trapframe

	action := handle_exception(cause, mut trapframe)

	match action {
		.resume_curr {
			curr_process.trapframe.epc += 4
		}
		.reschedule {
			curr_process.trapframe.epc += 4

			if curr_process.state == .running {
				curr_process.state = .ready
			}

			mut next_process := kernel.scheduler.pick_next() or {
				panic('No ready/runnable process after trap')
			}
			kernel.dispatcher.switch_to(mut next_process)
		}
		.terminate_curr {
			// TODO: kill process
			panic('Terminating current process')
		}
	}
}
