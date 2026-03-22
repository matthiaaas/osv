module proc

pub struct Scheduler {
pub mut:
	curr_pid u32
	processes [64]Process
}

fn (scheduler &Scheduler) index_of(pid u32) ?int {
	for i, process in scheduler.processes {
		if process.pid == pid {
			return i
		}
	}
	return none
}

pub fn (scheduler &Scheduler) by_pid(pid u32) ?&Process {
	if idx := scheduler.index_of(pid) {
		return unsafe { &scheduler.processes[idx] }
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
		process := unsafe { &scheduler.processes[idx] }

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

	panic("No space for new process")
}

pub fn (mut scheduler Scheduler) current() ?&Process {
	return scheduler.by_pid(scheduler.curr_pid)
}
