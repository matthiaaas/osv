module main

@[export: "kmain"]
fn kmain() {
	Uart.put(72) // H
	Uart.put(101) // e
	Uart.put(108) // l
	Uart.put(108) // l
	Uart.put(111) // o
	Uart.put(44)  // ,
	Uart.put(32)  //
	Uart.put(87)  // W
	Uart.put(111) // o
	Uart.put(114) // r
	Uart.put(108) // l
	Uart.put(100) // d
	Uart.put(10)  // \n

	mut i := u8(0)
	for {
		i++
		
	}
}

fn main() {
	kmain()
}
