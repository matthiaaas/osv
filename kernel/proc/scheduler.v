module proc

pub struct Scheduler {
mut:
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

pub fn (scheduler &Scheduler) pick_next(last_pid u32) ?&Process {
	start := if idx := scheduler.index_of(last_pid) {
		(idx + 1) % scheduler.processes.len
	} else {
		0
	}

	for i in 0 .. scheduler.processes.len {
		idx := (start + i) % scheduler.processes.len
		process := unsafe { &scheduler.processes[idx]}

		if process.state == .ready {
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
