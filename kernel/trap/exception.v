module trap

import proc { TrapFrame }

pub enum TrapDisposition {
	resume_curr
	reschedule
	terminate_curr
}

pub enum TrapCause as u32 {
	illegal_instruction = 2
	breakpoint = 3
	environment_call = 8
}

pub fn handle_exception(cause TrapCause, mut trapframe TrapFrame) TrapDisposition {
	match cause {
		.illegal_instruction {
			return .terminate_curr
		}
		.breakpoint {
			return .resume_curr
		}
		.environment_call {
			handle_syscall(trapframe.a7, mut trapframe) or { panic('Failed to handle syscall') }
			return .reschedule
		}
	}
}
