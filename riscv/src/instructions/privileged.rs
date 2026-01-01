use crate::{cpu::Cpu, isa::Instr, trap::Trap};

pub fn is_privileged(instr: Instr) -> bool {
    matches!(instr.funct3(), 0b000)
}

pub fn exec_privileged(_cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();
    let funct12 = i.imm() as u32;

    match funct12 {
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}
