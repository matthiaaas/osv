use std::fmt;

pub mod csr_addr {
    pub const MSTATUS: u16 = 0x300;
    pub const MISA: u16 = 0x301;
    pub const MIE: u16 = 0x304;
    pub const MTVEC: u16 = 0x305;

    pub const MSCRATCH: u16 = 0x340;
    pub const MEPC: u16 = 0x341;
    pub const MCAUSE: u16 = 0x342;
    pub const MTVAL: u16 = 0x343;
    pub const MIP: u16 = 0x344;

    pub const SATP: u16 = 0x180;

    pub const MCYCLE: u16 = 0xB00;
    pub const MINSTRET: u16 = 0xB02;
}

const MSTATUS_MIE: u32 = 1 << 3;
const MSTATUS_MPIE: u32 = 1 << 7;
const MSTATUS_MPP: u32 = 0b11 << 11;

pub struct CsrFile {
    mstatus: u32,
    misa: u32,
    mie: u32,
    mtvec: u32,

    mscratch: u32,
    mepc: u32,
    mcause: u32,
    mtval: u32,
    mip: u32,

    satp: u32,

    mcycle: u64,
    minstret: u64,
}

impl CsrFile {
    pub fn new() -> Self {
        Self {
            mstatus: 0,
            misa: 0x40001100, // rv32i
            mie: 0,
            mtvec: 0,

            mscratch: 0,
            mepc: 0,
            mcause: 0,
            mtval: 0,
            mip: 0,

            satp: 0,

            mcycle: 0,
            minstret: 0,
        }
    }

    pub fn read(&self, addr: u16) -> Result<u32, ()> {
        // TODO: privilege checks

        match addr {
            csr_addr::MSTATUS => Ok(self.mstatus),
            csr_addr::MISA => Ok(self.misa),
            csr_addr::MIE => Ok(self.mie),
            csr_addr::MTVEC => Ok(self.mtvec),
            csr_addr::MSCRATCH => Ok(self.mscratch),
            csr_addr::MEPC => Ok(self.mepc),
            csr_addr::MCAUSE => Ok(self.mcause),
            csr_addr::MTVAL => Ok(self.mtval),
            csr_addr::MIP => Ok(self.mip),
            csr_addr::SATP => Ok(self.satp),
            csr_addr::MCYCLE => Ok((self.mcycle & 0xFFFF_FFFF) as u32),
            csr_addr::MINSTRET => Ok((self.minstret & 0xFFFF_FFFF) as u32),
            _ => Err(()),
        }
    }

    pub fn write(&mut self, addr: u16, val: u32) -> Result<(), ()> {
        // TODO: privilege checks

        match addr {
            csr_addr::MSTATUS => {
                self.mstatus = val & 0x00001888; // wpri
                Ok(())
            }
            csr_addr::MISA => {
                self.misa = val;
                Ok(())
            }
            csr_addr::MIE => {
                self.mie = val;
                Ok(())
            }
            csr_addr::MTVEC => {
                self.mtvec = val;
                Ok(())
            }
            csr_addr::MSCRATCH => {
                self.mscratch = val;
                Ok(())
            }
            csr_addr::MEPC => {
                self.mepc = val & !0x3; // 4 byte align
                Ok(())
            }
            csr_addr::MCAUSE => {
                self.mcause = val;
                Ok(())
            }
            csr_addr::MTVAL => {
                self.mtval = val;
                Ok(())
            }
            csr_addr::MIP => {
                self.mip = val & 0x888; // msip, mtip, meip only
                Ok(())
            }
            csr_addr::SATP => {
                self.satp = val;
                Ok(())
            }
            csr_addr::MCYCLE => {
                self.mcycle = (self.mcycle & 0xFFFF_FFFF_0000_0000) | (val as u64);
                Ok(())
            }
            csr_addr::MINSTRET => {
                self.minstret = (self.minstret & 0xFFFF_FFFF_0000_0000) | (val as u64);
                Ok(())
            }
            _ => Err(()),
        }
    }

    pub fn set_exception_pc(&mut self, pc: u32) {
        self.mepc = pc;
    }

    pub fn set_cause(&mut self, cause: u32) {
        self.mcause = cause;
    }

    pub fn set_mtval(&mut self, value: u32) {
        self.mtval = value;
    }

    pub fn get_mtvec(&self) -> u32 {
        self.mtvec & !0b11
    }

    pub fn get_mepc(&self) -> u32 {
        self.mepc
    }

    pub fn get_cycle(&self) -> u64 {
        self.mcycle
    }

    pub fn get_mie(&self) -> bool {
        (self.mstatus & MSTATUS_MIE) != 0
    }

    pub fn get_mpie(&self) -> bool {
        (self.mstatus & MSTATUS_MPIE) != 0
    }

    pub fn get_mpp(&self) -> u8 {
        ((self.mstatus & MSTATUS_MPP) >> 11) as u8
    }

    pub fn get_satp(&self) -> u32 {
        self.satp
    }

    pub fn set_satp(&mut self, value: u32) {
        self.satp = value;
    }

    pub fn increment_cycle(&mut self) {
        self.mcycle = self.mcycle.wrapping_add(1);
    }

    pub fn increment_instret(&mut self) {
        self.minstret = self.minstret.wrapping_add(1);
    }

    pub fn enter_exception_mode(&mut self) {
        self.mstatus &= !MSTATUS_MIE;

        if self.get_mie() {
            self.mstatus |= MSTATUS_MPIE;
        } else {
            self.mstatus &= !MSTATUS_MPIE;
        }

        self.mstatus |= MSTATUS_MPP;
    }

    pub fn return_from_exception_mode(&mut self) {
        if self.get_mpie() {
            self.mstatus |= MSTATUS_MIE;
        } else {
            self.mstatus &= !MSTATUS_MIE;
        }

        self.mstatus &= !MSTATUS_MPIE;
        self.mstatus &= !MSTATUS_MPP;
    }
}

impl Default for CsrFile {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Debug for CsrFile {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut ds = f.debug_struct("CsrFile");
        if self.mstatus != 0 {
            ds.field("mstatus", &format_args!("{:#010x}", self.mstatus));
        }
        if self.misa != 0 {
            ds.field("misa", &format_args!("{:#010x}", self.misa));
        }
        if self.mie != 0 {
            ds.field("mie", &format_args!("{:#010x}", self.mie));
        }
        if self.mtvec != 0 {
            ds.field("mtvec", &format_args!("{:#010x}", self.mtvec));
        }
        if self.mepc != 0 {
            ds.field("mepc", &format_args!("{:#010x}", self.mepc));
        }
        if self.mcause != 0 {
            ds.field("mcause", &format_args!("{:#010x}", self.mcause));
        }
        if self.mtval != 0 {
            ds.field("mtval", &format_args!("{:#010x}", self.mtval));
        }
        if self.mcycle != 0 {
            ds.field("mcycle", &format_args!("{:#018x}", self.mcycle));
        }
        if self.minstret != 0 {
            ds.field("minstret", &format_args!("{:#018x}", self.minstret));
        }
        ds.finish()
    }
}
