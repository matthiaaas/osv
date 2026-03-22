use crate::{
    cpu::Cpu,
    isa::opcodes::SFENCE_VMA_FUNCT7,
    isa::{Instr, PrivilegeMode},
    trap::{Exception, Trap},
};

pub fn is_privileged(instr: Instr) -> bool {
    matches!(instr.funct3(), 0b000) // TODO: misses other instrs
}

pub fn exec_privileged(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    if instr.funct3() == 0b000 && instr.funct7() == SFENCE_VMA_FUNCT7 {
        // SFENCE.VMA
        let r = instr.as_r_type();
        if r.rd() != 0 {
            return Err(Trap::Exception(Exception::IllegalInstruction(instr)));
        }
        if cpu.priv_mode == PrivilegeMode::User {
            return Err(Trap::Exception(Exception::IllegalInstruction(instr)));
        }
        return Ok(());
    }

    let i = instr.as_i_type();
    let funct12 = i.imm() as u32;

    match funct12 {
        0x000 => {
            // ECALL
            Err(Trap::Exception(Exception::EnvironmentCall(cpu.priv_mode)))
        }
        0x302 => {
            // MRET
            let mpp = cpu.csr_file.get_mpp();
            cpu.priv_mode = PrivilegeMode::from(mpp);

            cpu.csr_file.return_from_exception_mode();

            cpu.next_pc = cpu.csr_file.get_mepc();

            Ok(())
        }
        _ => Err(Trap::Exception(Exception::IllegalInstruction(instr))),
    }
}
