module loader

import memory { Pagetable, VirtAddr }

pub struct LoadedProgram {
pub:
	entry     VirtAddr
	stack_top VirtAddr
}

pub interface ProgramLoader {
	load(mut pagetable Pagetable) !LoadedProgram
}
