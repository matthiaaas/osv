use crate::{cpu::Cpu, isa::Instr, trap::Trap};

pub fn is_privileged(instr: Instr) -> bool {
    matches!(instr.funct3(), 0b000) // TODO: misses other instrs
}

pub fn exec_privileged(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();
    let funct12 = i.imm() as u32;

    match funct12 {
        0b000000000000 => {
            // ECALL
            Err(Trap::EnvironmentCall(cpu.priv_mode))
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}
