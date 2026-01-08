module main

import riscv

@[export: "trap_handler"]
fn trap_handler() {
	Uart.puts("Trap occurred!\n")

	// riscv.mret()

	for {}
}
