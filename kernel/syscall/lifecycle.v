module syscall

import proc { TrapFrame }

pub const sys_getpid = u32(172)
pub const sys_yield = u32(124)
pub const sys_exit = u32(93)

pub fn handle_syscall(sysno u32) {
	match sysno {

	}
}
