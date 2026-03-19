mod cpu;
mod csrs;
mod debug;
mod devices;
mod instructions;
mod isa;
mod profiling;
mod regs;
mod trap;

use goblin::elf::{self, program_header};
use std::fs;
use std::path::Path;

use crate::cpu::Cpu;
use crate::devices::{Bus, Disk, Dram, Uart};
use crate::profiling::IpsMonitor;

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
    load_elf_into_ram(
        "/Users/matthias/Documents/private/projects/osv/kernel/target/kernel.elf",
        &mut ram,
        0x8000_0000,
    )
    .expect("Failed to load kernel ELF into RAM");

    let disk = Disk::new("/Users/matthias/Documents/private/projects/osv/kernel/target/disk")
        .expect("Failed to load disk file.");

    let mut bus = Bus::new();
    bus.map_to(0x8000_0000, Box::new(ram));
    bus.map_to(0x1000_0000, Box::new(uart0));
    bus.map_to(0x1000_1000, Box::new(disk));

    let mut cpu = Cpu::new(bus, None);

    let mut ips_monitor = IpsMonitor::default();
    loop {
        cpu.step();
        ips_monitor.update(cpu.cycles());
    }
}
