use crate::{cpu::Cpu, isa::Instr, trap::Trap};

pub fn exec_csr(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();
    let csr_addr = i.imm() as u16;
    let rd = i.rd();
    let rs1 = i.rs1();
    let funct3 = instr.funct3();

    match funct3 {
        0b001 => {
            // CSRRW
            let csr_val = cpu
                .csr_file
                .read(csr_addr)
                .map_err(|_| Trap::IllegalInstruction(instr))?;
            let rs1_val = cpu.reg_file.read(rs1);
            cpu.csr_file
                .write(csr_addr, rs1_val)
                .map_err(|_| Trap::IllegalInstruction(instr))?;
            cpu.reg_file.write(rd, csr_val);
            Ok(())
        }
        0b010 => {
            // CSRRS
            let csr_val = cpu
                .csr_file
                .read(csr_addr)
                .map_err(|_| Trap::IllegalInstruction(instr))?;
            let rs1_val = cpu.reg_file.read(rs1);
            let new_csr_val = csr_val | rs1_val;
            cpu.csr_file
                .write(csr_addr, new_csr_val)
                .map_err(|_| Trap::IllegalInstruction(instr))?;
            cpu.reg_file.write(rd, csr_val);
            Ok(())
        }
        0b011 => {
            // CSRRC
            let csr_val = cpu
                .csr_file
                .read(csr_addr)
                .map_err(|_| Trap::IllegalInstruction(instr))?;
            let rs1_val = cpu.reg_file.read(rs1);
            let new_csr_val = csr_val & !rs1_val;
            cpu.csr_file
                .write(csr_addr, new_csr_val)
                .map_err(|_| Trap::IllegalInstruction(instr))?;
            cpu.reg_file.write(rd, csr_val);
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}
