mod bus;
mod cpu;
mod csrs;
mod dram;
mod instructions;
mod isa;
mod regs;
mod trap;
mod uart;

use goblin::elf::{self, program_header};
use std::fs;
use std::path::Path;

use bus::Bus;
use cpu::Cpu;
use dram::Dram;
use uart::Uart;

fn load_elf_into_ram(filename: &str, ram: &mut Dram, base_addr: u32) -> Result<(), String> {
    let filepath = Path::new(filename);
    let elf_data = fs::read(filepath).map_err(|e| format!("Failed to read ELF file: {}", e))?;

    let elf = elf::Elf::parse(&elf_data).map_err(|e| format!("Failed to parse ELF: {}", e))?;

    for ph in elf.program_headers {
        if ph.p_type == program_header::PT_LOAD {
            let file_offset = ph.p_offset as usize;
            let mem_addr = ph.p_vaddr as u32 - base_addr;
            let file_size = ph.p_filesz as usize;
            let _mem_size = ph.p_memsz as usize;

            let segment_data = &elf_data[file_offset..file_offset + file_size];
            ram.flash(mem_addr, segment_data)
                .map_err(|e| format!("Failed to load segment into RAM: {:?}", e))?;
        }
    }

    Ok(())
}

fn main() {
    let uart0 = Uart::new();

    let mut ram = Dram::new(1024 * 1024); // 1 MB RAM
    // let program = vec![
    //     0x13, 0x05, 0x00, 0x00, // addi a0, zero, 0
    //     0x93, 0x05, 0x05, 0x01, // addi a1, a0, 16,
    //     0xb3, 0x85, 0xb5, 0x00, // add a1, a1, a1
    // ];
    // ram.flash(0x0, &program).expect("RAM too sparse");
    load_elf_into_ram(
        &mut ram,
        0x8000_0000,
    )
    .expect("Failed to load ELF into RAM");

    let mut bus = Bus::new();
    bus.map_to(0x8000_0000, Box::new(ram));
    bus.map_to(0x1000_0000, Box::new(uart0));

    let mut cpu = Cpu::new(bus, None);

    while cpu.cycle < 10 {
        cpu.step();
        println!("{:?}", cpu.reg_file);
    }
}
