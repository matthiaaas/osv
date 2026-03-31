module proc

const max_processes = 32

pub struct Scheduler {
pub mut:
	curr_pid    u32
	pid_counter u32
	processes   [max_processes]Process
}

fn (scheduler &Scheduler) index_of(pid u32) ?int {
	for i in 0 .. scheduler.processes.len {
		if scheduler.processes[i].pid == pid {
			return i
		}
	}
	return none
}

pub fn (scheduler &Scheduler) by_pid(pid u32) ?&Process {
	if idx := scheduler.index_of(pid) {
		return &scheduler.processes[idx]
	}
	return none
}

pub fn (mut scheduler Scheduler) pick_next() ?&Process {
	start := if idx := scheduler.index_of(scheduler.curr_pid) {
		(idx + 1) % scheduler.processes.len
	} else {
		0
	}

	for i in 0 .. scheduler.processes.len {
		idx := (start + i) % scheduler.processes.len
		process := &scheduler.processes[idx]

		if process.state == .ready {
			scheduler.curr_pid = process.pid
			return process
		}
	}

	return none
}

pub fn (mut scheduler Scheduler) enqueue(process Process) {
	for i in 0 .. scheduler.processes.len {
		if scheduler.processes[i].state == .unused {
			scheduler.processes[i] = process
			return
		}
	}
	panic('No space for new process: ${process.pid}')
}

pub fn (mut scheduler Scheduler) current() ?&Process {
	return scheduler.by_pid(scheduler.curr_pid)
}

pub fn (mut scheduler Scheduler) zombify(mut process Process, exit_status int) {
	process.state = .zombie
	process.exit_status = exit_status
}

pub fn (mut scheduler Scheduler) fork(mut process Process) !Process {
	child_pid := scheduler.next_pid()
	child_pagetable := process.pagetable.clone() or {
		return error('Failed to clone pagetable: ${err}')
	}
	child_process := Process{
		pid:              child_pid
		state:            .ready
		pagetable:        child_pagetable
		trapframe:        process.trapframe
		file_descriptors: process.file_descriptors
		kernel_stack_top: process.kernel_stack_top
		parent_pid:       process.pid
		exit_status:      none
	}
	return child_process
}

pub fn (mut scheduler Scheduler) next_pid() u32 {
	pid := scheduler.pid_counter
	scheduler.pid_counter++
	return pid
}
