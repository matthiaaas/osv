@[export: "main"] // Export main so the linker can find it
fn main() {
    // Your bare metal code here
    // e.g., writing to a pointer for UART output
    unsafe {
        mut uart := &int(0x10000000) // Example UART address
        *uart = 72 // 'H'
    }
    for {}
}

// module main

// import riscv

// fn main() {
//     // addi := riscv.isa.Instr.from(0x00500093)
// 	// assert addi.opcode() == 0x13

// 	cpu := riscv.Cpu.new()

//     println("Hello World")
// }
