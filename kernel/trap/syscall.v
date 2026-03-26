module trap

import proc { Process }

pub const sys_getpid = u32(172)
pub const sys_clone = u32(220) // fork etc.
pub const sys_execve = u32(221) // replace curr process image
pub const sys_exit = u32(93) // terminate current process
pub const sys_wait4 = u32(260) // suspend execution until child proc state changes
pub const sys_yield = u32(124)

pub const sys_brk = u32(214) // program break
pub const sys_mmap = u32(222)
pub const sys_munmap = u32(215)

pub const sys_openat = u32(56)
pub const sys_close = u32(57)
pub const sys_read = u32(63)
pub const sys_write = u32(64)
pub const sys_lseek = u32(62)
pub const sys_newfstatat = u32(79)

pub fn handle_syscall(sysno u32, mut curr_process Process) !TrapDisposition {
	match sysno {
		sys_getpid {
			curr_process.trapframe.a0 = curr_process.pid
			return .reschedule
		}
		sys_exit {
			kernel.scheduler.zombify(mut curr_process, int(curr_process.trapframe.a0))
			return .terminate_curr
		}
		sys_yield {
			curr_process.trapframe.a0 = 0
			return .reschedule
		}
		sys_openat {
			path := unsafe { byteptr(curr_process.trapframe.a0).vstring() }

			// mount_id, mount := kernel.vfs.resolve(path) or { return error('Failed to resolve path') }

			return .reschedule
		}
		sys_read {
			fd := curr_process.trapframe.a0
			buf_ptr := curr_process.trapframe.a1
			len := curr_process.trapframe.a2
			// open_file := kernel.global_file_table.at(curr_process.file_descriptors[fd])
			return .reschedule
		}
		else {
			return error('Unimplemented syscall=${sysno}')
		}
	}
}
