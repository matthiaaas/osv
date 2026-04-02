module proc

import riscv
import memory { Pagetable, VirtAddr, map_kernel_regions }
import loader { ProgramLoader }

pub enum ProcessState {
	unused
	ready
	running
	sleeping
	zombie
}

pub struct Process {
pub:
	pid u32
pub mut:
	state            ProcessState
	pagetable        Pagetable
	trapframe        TrapFrame
	file_descriptors FileDescriptorTable
	kernel_stack_top u32
	parent_pid       ?u32
	exit_status      ?int
}

pub fn Process.new(pid u32,
	pagetable Pagetable,
	program_counter VirtAddr,
	stack_top VirtAddr,
	kernel_stack_top u32,
	parent_pid ?u32) Process {
	return Process{
		pid:              pid
		state:            .ready
		pagetable:        pagetable
		trapframe:        TrapFrame{
			epc: program_counter
			sp:  stack_top
		}
		file_descriptors: FileDescriptorTable.new()
		kernel_stack_top: kernel_stack_top
		parent_pid:       parent_pid
		exit_status:      none
	}
}

pub fn Process.bootstrap(pid u32, l ProgramLoader) !Process {
	mut pagetable := Pagetable.new()!

	loaded_program := l.load(mut pagetable)!

	// TODO: allocate contiguous frames in a single safe call OR even better: stop identity mapping all kernel regions
	kernel_stack_frame_1 := kernel.frame_allocator.allocate() or {
		return error('Failed to allocate kernel stack frame')
	}
	kernel_stack_frame_2 := kernel.frame_allocator.allocate() or {
		return error('Failed to allocate kernel stack frame')
	}
	kernel_stack_top := u32(kernel_stack_frame_1) + riscv.page_size
	map_kernel_regions(pagetable) or { return error('Failed to map kernel') }

	return Process.new(pid, pagetable, loaded_program.entry, loaded_program.stack_top,
		kernel_stack_top, none)
}
