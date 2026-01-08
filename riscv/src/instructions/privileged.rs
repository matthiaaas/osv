use crate::{
    cpu::Cpu,
    isa::{Instr, PrivilegeMode},
    trap::Trap,
};

pub fn is_privileged(instr: Instr) -> bool {
    matches!(instr.funct3(), 0b000) // TODO: misses other instrs
}

pub fn exec_privileged(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();
    let funct12 = i.imm() as u32;

    match funct12 {
        0x000 => {
            // ECALL
            Err(Trap::EnvironmentCall(cpu.priv_mode))
        }
        0x302 => {
            // MRET
            let mpp = cpu.csr_file.get_mpp();
            cpu.priv_mode = PrivilegeMode::from(mpp);

            cpu.csr_file.return_from_exception_mode();

            cpu.next_pc = cpu.csr_file.get_mepc();

            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}
