use crate::{cpu::Cpu, isa::Instr, trap::Trap};

pub fn exec_op_imm(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();

    match instr.funct3() {
        0b000 => {
            // ADDI
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

pub fn exec_op_reg(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let r = instr.as_r_type();

    match instr.funct3() {
        0b000 => {
            // ADD
            let rd = r.rd();
            let rs1 = r.rs1();
            let rs2 = r.rs2();
            let res = cpu.reg_file.read(rs1).wrapping_add(cpu.reg_file.read(rs2));
            cpu.reg_file.write(rd, res);
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}

pub fn exec_auipc(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let u = instr.as_u_type();

    let rd = u.rd();
    let imm = u.imm();

    let result = cpu.pc.wrapping_add(imm as u32);
    cpu.reg_file.write(rd, result);

    Ok(())
}

pub fn exec_jal(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let j = instr.as_j_type();

    let rd = j.rd();
    let imm = j.imm();

    let ret_addr = cpu.next_pc;
    let target_addr = cpu.pc.wrapping_add(imm as u32);

    cpu.reg_file.write(rd, ret_addr);
    cpu.next_pc = target_addr;

    Ok(())
}

pub fn exec_jalr(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();

    let rd = i.rd();
    let rs1 = i.rs1();
    let imm = i.imm();

    let ret_addr = cpu.next_pc;
    let base_addr = cpu.reg_file.read(rs1);
    let target_addr = base_addr.wrapping_add(imm as u32) & !1;

    cpu.reg_file.write(rd, ret_addr);
    cpu.next_pc = target_addr;

    Ok(())
}
