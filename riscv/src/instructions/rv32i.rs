use crate::{cpu::Cpu, isa::Instr, trap::Trap};

pub fn exec_op_imm(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();

    match instr.funct3() {
        0b000 => {
            let rd = i.rd();
            let rs1 = i.rs1();
            let imm = i.imm();
            let res = (cpu.reg_file.read(rs1) as i32) + imm;
            cpu.reg_file.write(rd, res as u32);
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}
