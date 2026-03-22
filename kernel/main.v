module main

import trap as _

#include "symbols.h"

fn C._vinit(argc int, argv voidptr)

@[export: 'kmain']
fn kmain() {
	C._vinit(0, unsafe { nil })

	Kernel.boot()

	kernel.run()

	for {}
}

fn main() {
	kmain()
}
