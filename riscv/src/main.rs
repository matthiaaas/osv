mod bus;
mod cpu;
mod dram;
mod instructions;
mod isa;
mod registers;
mod trap;
mod uart;

use bus::Bus;
use cpu::Cpu;
use dram::Dram;
use uart::Uart;

fn main() {
    let uart0 = Uart::new();

    let mut ram = Dram::new(1024 * 1024); // 1 MB RAM
    let program = vec![
        0x13, 0x05, 0x00, 0x00, // addi a0, zero, 0
        0x93, 0x05, 0x05, 0x01, // addi a1, a0, 16
    ];
    ram.flash(&program, 0x0).expect("RAM too sparse");

    let mut bus = Bus::new();
    bus.map_to(0x8000_0000, Box::new(ram));
    bus.map_to(0x1000_0000, Box::new(uart0));

    let mut cpu = Cpu::new(bus, None);

    cpu.step();
    cpu.step();

    println!("{:?}", cpu.reg_file);
}
