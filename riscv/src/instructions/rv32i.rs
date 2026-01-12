use crate::{cpu::Cpu, isa::Instr, trap::Trap};

pub fn exec_op_imm(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();

    match instr.funct3() {
        0b000 => {
            // ADDI
            let res = (cpu.reg_file.read(i.rs1()) as i32).wrapping_add(i.imm());
            cpu.reg_file.write(i.rd(), res as u32);
            Ok(())
        }
        0b010 => {
            // SLTI (Set Less Than Imm)
            let rs1_val = cpu.reg_file.read(i.rs1()) as i32;
            let imm_val = i.imm();
            if rs1_val < imm_val {
                cpu.reg_file.write(i.rd(), 1);
            } else {
                cpu.reg_file.write(i.rd(), 0);
            }
            Ok(())
        }
        0b011 => {
            // SLTIU (Set Less Than Imm Unsigned)
            todo!()
        }
        0b100 => {
            // XORI
            let res = cpu.reg_file.read(i.rs1()) ^ (i.imm() as u32);
            cpu.reg_file.write(i.rd(), res);
            Ok(())
        }
        0b110 => {
            // ORI
            let res = cpu.reg_file.read(i.rs1()) | (i.imm() as u32);
            cpu.reg_file.write(i.rd(), res);
            Ok(())
        }
        0b111 => {
            // ANDI
            let res = cpu.reg_file.read(i.rs1()) & (i.imm() as u32);
            cpu.reg_file.write(i.rd(), res);
            Ok(())
        }

        0b001 => {
            // SLLI
            let shamt = (i.imm() & 0x1f) as u32;
            let res = cpu.reg_file.read(i.rs1()) << shamt;
            cpu.reg_file.write(i.rd(), res);
            Ok(())
        }
        0b101 => {
            let shamt = (i.imm() & 0x1f) as u32;
            match instr.funct7() {
                0x00 => {
                    // SRLI
                    let res = cpu.reg_file.read(i.rs1()) >> shamt;
                    cpu.reg_file.write(i.rd(), res);
                }
                0x20 => {
                    // SRAI
                    let rs1_val = cpu.reg_file.read(i.rs1()) as i32;
                    let res = (rs1_val >> shamt) as u32;
                    cpu.reg_file.write(i.rd(), res);
                }
                _ => return Err(Trap::IllegalInstruction(instr)),
            }
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}

pub fn exec_op_reg(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let r = instr.as_r_type();

    match instr.funct3() {
        0b000 => {
            // ADD / SUB
            match instr.funct7() {
                0x00 => {
                    // ADD
                    let res = cpu
                        .reg_file
                        .read(r.rs1())
                        .wrapping_add(cpu.reg_file.read(r.rs2()));
                    cpu.reg_file.write(r.rd(), res);
                    Ok(())
                }
                0x20 => {
                    // SUB
                    let res = cpu
                        .reg_file
                        .read(r.rs1())
                        .wrapping_sub(cpu.reg_file.read(r.rs2()));
                    cpu.reg_file.write(r.rd(), res);
                    Ok(())
                }
                _ => Err(Trap::IllegalInstruction(instr)),
            }
        }
        0b001 => {
            // SLL
            todo!()
        }
        0b010 => {
            // SLT
            todo!()
        }
        0b011 => {
            // SLTU
            let rs1_val = cpu.reg_file.read(r.rs1());
            let rs2_val = cpu.reg_file.read(r.rs2());
            if rs1_val < rs2_val {
                cpu.reg_file.write(r.rd(), 1);
            } else {
                cpu.reg_file.write(r.rd(), 0);
            }
            Ok(())
        }
        0b100 => {
            // XOR
            let res = cpu.reg_file.read(r.rs1()) ^ cpu.reg_file.read(r.rs2());
            cpu.reg_file.write(r.rd(), res);
            Ok(())
        }
        0b101 => {
            match instr.funct7() {
                0x00 => {
                    // SRL
                    let rs1_val = cpu.reg_file.read(r.rs1());
                    let rs2_val = cpu.reg_file.read(r.rs2()) & 0x1f;
                    let res = rs1_val >> rs2_val;
                    cpu.reg_file.write(r.rd(), res);
                    Ok(())
                }
                0x20 => {
                    // SRA^
                    todo!()
                }
                _ => Err(Trap::IllegalInstruction(instr)),
            }
        }
        0b110 => {
            // OR
            let res = cpu.reg_file.read(r.rs1()) | cpu.reg_file.read(r.rs2());
            cpu.reg_file.write(r.rd(), res);
            Ok(())
        }
        0b111 => {
            // AND
            let res = cpu.reg_file.read(r.rs1()) & cpu.reg_file.read(r.rs2());
            cpu.reg_file.write(r.rd(), res);
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}

pub fn exec_lui(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let u = instr.as_u_type();
    cpu.reg_file.write(u.rd(), u.imm() as u32);
    Ok(())
}

pub fn exec_auipc(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let u = instr.as_u_type();
    let result = cpu.pc.wrapping_add(u.imm() as u32);
    cpu.reg_file.write(u.rd(), result);
    Ok(())
}

pub fn exec_jal(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let j = instr.as_j_type();

    let ret_addr = cpu.next_pc;
    let target_addr = cpu.pc.wrapping_add(j.imm() as u32);

    cpu.reg_file.write(j.rd(), ret_addr);
    cpu.next_pc = target_addr;

    Ok(())
}

pub fn exec_jalr(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();

    let ret_addr = cpu.next_pc;
    let base_addr = cpu.reg_file.read(i.rs1());
    let target_addr = base_addr.wrapping_add(i.imm() as u32) & !1;

    cpu.reg_file.write(i.rd(), ret_addr);
    cpu.next_pc = target_addr;

    Ok(())
}

pub fn exec_branch(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let b = instr.as_b_type();

    match instr.funct3() {
        0b000 => {
            // BEQ
            let rs1_val = cpu.reg_file.read(b.rs1());
            let rs2_val = cpu.reg_file.read(b.rs2());
            if rs1_val == rs2_val {
                let target_addr = cpu.pc.wrapping_add(b.imm() as u32);
                cpu.next_pc = target_addr;
            }
            Ok(())
        }
        0b001 => {
            // BNE
            let rs1_val = cpu.reg_file.read(b.rs1());
            let rs2_val = cpu.reg_file.read(b.rs2());
            if rs1_val != rs2_val {
                let target_addr = cpu.pc.wrapping_add(b.imm() as u32);
                cpu.next_pc = target_addr;
            }
            Ok(())
        }
        0b100 => {
            // BLT
            let rs1_val = cpu.reg_file.read(b.rs1()) as i32;
            let rs2_val = cpu.reg_file.read(b.rs2()) as i32;
            if rs1_val < rs2_val {
                let target_addr = cpu.pc.wrapping_add(b.imm() as u32);
                cpu.next_pc = target_addr;
            }
            Ok(())
        }
        0b101 => {
            // BGE
            let rs1_val = cpu.reg_file.read(b.rs1()) as i32;
            let rs2_val = cpu.reg_file.read(b.rs2()) as i32;
            if rs1_val >= rs2_val {
                let target_addr = cpu.pc.wrapping_add(b.imm() as u32);
                cpu.next_pc = target_addr;
            }
            Ok(())
        }
        0b110 => {
            // BLTU
            let rs1_val = cpu.reg_file.read(b.rs1());
            let rs2_val = cpu.reg_file.read(b.rs2());
            if rs1_val < rs2_val {
                let target_addr = cpu.pc.wrapping_add(b.imm() as u32);
                cpu.next_pc = target_addr;
            }
            Ok(())
        }
        0b111 => {
            // BGEU
            let rs1_val = cpu.reg_file.read(b.rs1());
            let rs2_val = cpu.reg_file.read(b.rs2());
            if rs1_val >= rs2_val {
                let target_addr = cpu.pc.wrapping_add(b.imm() as u32);
                cpu.next_pc = target_addr;
            }
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}

pub fn exec_load(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let i = instr.as_i_type();

    match instr.funct3() {
        0b000 => {
            // LB (Load Byte, sign-extended)
            let addr = cpu.reg_file.read(i.rs1()).wrapping_add(i.imm() as u32);
            let phys_addr = cpu.translate(addr)?;
            let byte = cpu.bus.load(phys_addr, 1)? as u8;
            let value = (byte as i8) as i32;
            cpu.reg_file.write(i.rd(), value as u32);
            Ok(())
        }
        0b001 => {
            // LH (Load Half, sign-extended)
            let addr = cpu.reg_file.read(i.rs1()).wrapping_add(i.imm() as u32);
            let phys_addr = cpu.translate(addr)?;
            let halfword = cpu.bus.load(phys_addr, 2)? as u16;
            let value = (halfword as i16) as i32;
            cpu.reg_file.write(i.rd(), value as u32);
            Ok(())
        }
        0b010 => {
            // LW (Load Word)
            let addr = cpu.reg_file.read(i.rs1()).wrapping_add(i.imm() as u32);
            let phys_addr = cpu.translate(addr)?;
            let word = cpu.bus.load(phys_addr, 4)? as u32;
            cpu.reg_file.write(i.rd(), word);
            Ok(())
        }
        0b100 => {
            // LBU (Load Byte Unsigned, zero-extended)
            let addr = cpu.reg_file.read(i.rs1()).wrapping_add(i.imm() as u32);
            let phys_addr = cpu.translate(addr)?;
            let byte = cpu.bus.load(phys_addr, 1)? as u8;
            let value = byte as u32;
            cpu.reg_file.write(i.rd(), value);
            Ok(())
        }
        0b101 => {
            // LHU (Load Half Unsigned, zero-extended)
            let addr = cpu.reg_file.read(i.rs1()).wrapping_add(i.imm() as u32);
            let phys_addr = cpu.translate(addr)?;
            let halfword = cpu.bus.load(phys_addr, 2)? as u16;
            let value = halfword as u32;
            cpu.reg_file.write(i.rd(), value);
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}

pub fn exec_store(cpu: &mut Cpu, instr: Instr) -> Result<(), Trap> {
    let s = instr.as_s_type();

    match instr.funct3() {
        0b000 => {
            // SB
            let addr = cpu.reg_file.read(s.rs1()).wrapping_add(s.imm() as u32);
            let data = (cpu.reg_file.read(s.rs2()) & 0xff) as u8;
            let phys_addr = cpu.translate(addr)?;
            cpu.bus.store(phys_addr, 1, data as u32)?;
            Ok(())
        }
        0b001 => {
            // SH
            let addr = cpu.reg_file.read(s.rs1()).wrapping_add(s.imm() as u32);
            let data = (cpu.reg_file.read(s.rs2()) & 0xffff) as u16;
            let phys_addr = cpu.translate(addr)?;
            cpu.bus.store(phys_addr, 2, data as u32)?;
            Ok(())
        }
        0b010 => {
            // SW
            let addr = cpu.reg_file.read(s.rs1()).wrapping_add(s.imm() as u32);
            let data = cpu.reg_file.read(s.rs2());
            let phys_addr = cpu.translate(addr)?;
            cpu.bus.store(phys_addr, 4, data)?;
            Ok(())
        }
        _ => Err(Trap::IllegalInstruction(instr)),
    }
}
