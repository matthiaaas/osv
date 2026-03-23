module trap

import proc { Process }

pub enum TrapDisposition {
	resume_curr
	reschedule
	terminate_curr
}

pub enum ExceptionCause as u32 {
	illegal_instruction = 2
	breakpoint          = 3
	environment_call    = 8
}

pub fn handle_exception(cause ExceptionCause, mut curr_process Process) TrapDisposition {
	match cause {
		.illegal_instruction {
			return .terminate_curr
		}
		.breakpoint {
			return .resume_curr
		}
		.environment_call {
			return handle_syscall(curr_process.trapframe.a7, mut curr_process) or {
				panic('Failed to handle syscall')
			}
		}
	}
}
