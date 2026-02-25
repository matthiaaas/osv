// module main

// import memory { Pagetable }

// pub enum ProcState {
// 	unused
// 	running
// 	sleeping
// 	zombie
// }

// pub struct Process {
// mut:
// 	pid u32
// 	state ProcState
// 	pagetable Pagetable
// 	trapframe &TrapFrame
// 	kernel_sp voidptr
// }

// pub fn Process.new(pid u32) ?Process {
// 	stack_page := kmem.alloc()
// 	if stack_page == voidptr(0) {
// 		return none
// 	}

// 	trapframe_page := kmem.alloc()
// 	if trapframe_page == voidptr(0) {
// 		kmem.kfree(stack_page)
// 		return none
// 	}

// 	stack_top := voidptr(u32(stack_page) + kstack_size)
// 	trapframe := unsafe { &TrapFrame(trapframe_page) }

// 	return Process{
// 		pid: pid,
// 		state: .unused
// 		pagetable: Pagetable(0)
// 		trapframe: trapframe
// 		kernel_sp: stack_top
// 	}
// }

