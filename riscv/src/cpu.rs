use crate::bus::Bus;
use crate::instructions::rv32i;
use crate::isa::opcodes::OP_IMM;
use crate::isa::{INSTRUCTION_SIZE, Instr, PrivilegeMode};
use crate::registers::RegFile;
use crate::trap::Trap;

const DEFAULT_RESET_VECTOR: u32 = 0x8000_0000;

pub struct Cpu {
    pub pc: u32,
    pub next_pc: u32,
    pub reg_file: RegFile,
    pub bus: Bus,
    pub priv_mode: PrivilegeMode,
    pub cycle: u64,
}

impl Cpu {
    pub fn new(bus: Bus, reset_vector: Option<u32>) -> Self {
        let reset_vector = reset_vector.unwrap_or(DEFAULT_RESET_VECTOR);

        Self {
            pc: reset_vector,
            next_pc: reset_vector,
            reg_file: RegFile::new(),
            bus,
            priv_mode: PrivilegeMode::Machine,
            cycle: 0,
        }
    }

    pub fn fetch(&mut self) -> Result<Instr, Trap> {
        self.bus
            .load(self.pc, INSTRUCTION_SIZE)
            .map(Instr::from)
            .map_err(Trap::from)
    }

    pub fn execute(&mut self, instr: Instr) -> Result<(), Trap> {
        match instr.opcode() {
            OP_IMM => rv32i::exec_op_imm(self, instr),
            _ => Err(Trap::IllegalInstruction(instr)),
        }
    }

    pub fn step(&mut self) {
        if let Err(trap) = self.try_step() {
            self.handle_trap(trap);
        }

        self.pc = self.next_pc;
        self.cycle += 1;
    }

    fn try_step(&mut self) -> Result<(), Trap> {
        let instr = self.fetch()?;
        self.next_pc = self.pc.wrapping_add(INSTRUCTION_SIZE as u32);
        self.execute(instr)?;
        Ok(())
    }

    fn handle_trap(&mut self, trap: Trap) {
        panic!("Trap handling not implemented: {:?}", trap);
    }
}
