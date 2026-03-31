module trap

import file { SeekFrom }
import proc { LocalFileDescriptor, Process }

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
		sys_clone {
			mut child_process := kernel.scheduler.fork(mut curr_process) or {
				return error('Failed to fork: ${err}')
			}
			child_process.trapframe.a0 = 0
			curr_process.trapframe.a0 = child_process.pid
			kernel.scheduler.enqueue(child_process)
			return .reschedule
		}
		sys_openat {
			path := unsafe { byteptr(curr_process.trapframe.a1).vstring() }
			flags := curr_process.trapframe.a2
			mode := curr_process.trapframe.a3

			vnode := kernel.vfs.resolve(path) or { return error('Failed to resolve path: ${err}') }
			gft_fd := kernel.global_file_table.add(vnode, 0) or {
				return error('Failed to add open file: ${err}')
			}
			fd := curr_process.alloc_file_descriptor(gft_fd) or {
				return error('Failed to allocate file descriptor: ${err}')
			}
			curr_process.file_descriptors[fd] = gft_fd
			curr_process.trapframe.a0 = fd
			return .reschedule
		}
		sys_read {
			fd := u32(curr_process.trapframe.a0)
			buf_ptr := unsafe { byteptr(curr_process.trapframe.a1) }
			len := u32(curr_process.trapframe.a2)

			mut open_file := kernel.global_file_table.at(curr_process.file_descriptors[fd]) or {
				return error('Failed to get open file: ${err}')
			}
			open_file.read(buf_ptr, len) or {
				return error('Failed to read from open file: ${err}')
			}
			curr_process.trapframe.a0 = len
			return .reschedule
		}
		sys_write {
			fd := u32(curr_process.trapframe.a0)
			buf_ptr := unsafe { byteptr(curr_process.trapframe.a1) }
			len := u32(curr_process.trapframe.a2)

			mut open_file := kernel.global_file_table.at(curr_process.file_descriptors[fd]) or {
				return error('Failed to get open file: ${err}')
			}
			open_file.write(buf_ptr, len) or {
				return error('Failed to write to open file: ${err}')
			}
			curr_process.trapframe.a0 = len
			return .reschedule
		}
		sys_lseek {
			fd := u32(curr_process.trapframe.a0)
			offset := u32(curr_process.trapframe.a1)
			whence := u32(curr_process.trapframe.a2)

			mut open_file := kernel.global_file_table.at(curr_process.file_descriptors[fd]) or {
				return error('Failed to get open file: ${err}')
			}
			seek_from := SeekFrom.from2(whence) or { return error('Invalid whence') }
			open_file.lseek(offset, seek_from) or {
				return error('Failed to lseek open file: ${err}')
			}
			curr_process.trapframe.a0 = open_file.position
			return .reschedule
		}
		sys_close {
			fd := LocalFileDescriptor(u8(curr_process.trapframe.a0))
			kernel.global_file_table.close(curr_process.file_descriptors[fd]) or {
				return error('Failed to close open file: ${err}')
			}
			curr_process.file_descriptors[fd] = proc.invalid_open_file_descriptor
			return .reschedule
		}
		else {
			return error('Unimplemented syscall=${sysno}')
		}
	}
}
