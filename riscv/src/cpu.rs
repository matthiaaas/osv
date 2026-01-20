use crate::bus::Bus;
use crate::csrs::CsrFile;
use crate::instructions::{privileged, rv32i, zicsr};
use crate::isa::opcodes::{AUIPC, BRANCH, JAL, JALR, LOAD, LUI, OP_IMM, OP_REG, STORE, SYSTEM};
use crate::isa::{INSTRUCTION_SIZE, Instr, PrivilegeMode};
use crate::regs::RegFile;
use crate::trap::Trap;

const DEFAULT_RESET_VECTOR: u32 = 0x8000_0000;

pub struct Cpu {
    pub pc: u32,
    pub next_pc: u32,
    pub reg_file: RegFile,
    pub csr_file: CsrFile,
    pub bus: Bus,
    pub priv_mode: PrivilegeMode,
}

impl Cpu {
    pub fn new(bus: Bus, reset_vector: Option<u32>) -> Self {
        let reset_vector = reset_vector.unwrap_or(DEFAULT_RESET_VECTOR);

        Self {
            pc: reset_vector,
            next_pc: reset_vector,
            reg_file: RegFile::default(),
            csr_file: CsrFile::default(),
            bus,
            priv_mode: PrivilegeMode::Machine,
        }
    }

    pub fn fetch(&mut self) -> Result<Instr, Trap> {
        let phys_pc = self.translate(self.pc)?;
        self.bus
            .load(phys_pc, INSTRUCTION_SIZE)
            .map(Instr::from)
            .map_err(Trap::from)
    }

    pub fn execute(&mut self, instr: Instr) -> Result<(), Trap> {
        match instr.opcode() {
            OP_IMM => rv32i::exec_op_imm(self, instr),
            OP_REG => rv32i::exec_op_reg(self, instr),
            LUI => rv32i::exec_lui(self, instr),
            AUIPC => rv32i::exec_auipc(self, instr),
            JAL => rv32i::exec_jal(self, instr),
            JALR => rv32i::exec_jalr(self, instr),
            BRANCH => rv32i::exec_branch(self, instr),
            LOAD => rv32i::exec_load(self, instr),
            STORE => rv32i::exec_store(self, instr),
            SYSTEM => {
                if privileged::is_privileged(instr) {
                    privileged::exec_privileged(self, instr)
                } else {
                    zicsr::exec_csr(self, instr)
                }
            }
            _ => Err(Trap::IllegalInstruction(instr)),
        }
    }

    pub fn step(&mut self) {
        if let Err(trap) = self.try_step() {
            self.handle_trap(trap);
        } else {
            self.csr_file.increment_instret();
        }

        self.pc = self.next_pc;
        self.csr_file.increment_cycle();
    }

    pub fn cycles(&self) -> u64 {
        self.csr_file.get_cycle()
    }

    fn try_step(&mut self) -> Result<(), Trap> {
        let instr = self.fetch()?;
        self.next_pc = self.pc.wrapping_add(INSTRUCTION_SIZE as u32);
        self.execute(instr)?;
        Ok(())
    }

    fn handle_trap(&mut self, trap: Trap) {
        println!(
            "Trap occurred: {:?} at PC={:#010x}, {:?}",
            trap, self.pc, self.priv_mode
        );

        self.csr_file.set_exception_pc(self.pc);
        self.csr_file.set_cause(trap.cause_code() as u32);
        self.csr_file.set_mtval(trap.value());
        let prev_priv = self.priv_mode;
        self.csr_file.enter_exception_mode(prev_priv);

        self.priv_mode = PrivilegeMode::Machine;

        self.next_pc = self.csr_file.get_mtvec();
    }

    pub fn translate(&mut self, virt_addr: u32) -> Result<u32, Trap> {
        let satp = self.csr_file.get_satp();
        if satp & 0x8000_0000 == 0 {
            return Ok(virt_addr);
        }

        let root_ppn = satp & 0x003f_ffff;
        let root_pt_addr = root_ppn << 12;

        let vpn1 = (virt_addr >> 22) & 0x3ff;
        let pte1_addr = root_pt_addr + (vpn1 * 4);
        let pte1 = self.bus.load(pte1_addr, 4)?;

        let pt0_ppn = (pte1 >> 10) & 0x003f_ffff;
        let pt0_addr = pt0_ppn << 12;

        let vpn0 = (virt_addr >> 12) & 0x3ff;
        let pte0_addr = pt0_addr + (vpn0 * 4);
        let pte0 = self.bus.load(pte0_addr, 4)?;

        let final_ppn = (pte0 >> 10) & 0x003f_ffff;

        let offset = virt_addr & 0xfff;

        let phys_addr = (final_ppn << 12) | offset;
        Ok(phys_addr)
    }
}
