module main

#include "symbols.h"

fn C._vinit(argc int, argv voidptr)

@[export: 'kmain']
fn kmain() {
	C._vinit(0, unsafe { nil })

	Kernel.boot()

	kernel.run()

	for {}
}

// 	unsafe {
// 		code := &u32(user_code)
// 		code[0] = 0x00000513 // li a0, 0
// 		code[1] = 0x00000073 // ecall
// 		code[2] = 0x00000073 // ecall
// 		code[3] = 0x00000073 // ecall
// 		code[4] = 0x00000073 // ecall
// 		code[5] = 0x0000006f // j .
// 	}

fn main() {
	kmain()
}
