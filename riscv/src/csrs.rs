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

    pub const MCYCLE: u16 = 0xB00;
    pub const MINSTRET: u16 = 0xB02;
}

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
            csr_addr::MCYCLE => Ok((self.mcycle & 0xFFFF_FFFF) as u32),
            csr_addr::MINSTRET => Ok((self.minstret & 0xFFFF_FFFF) as u32),
            _ => Err(()),
        }
    }

    // pub fn write(&mut self, addr: u16, val: u32) -> Result<(), ()> {

    // }
}

impl Default for CsrFile {
    fn default() -> Self {
        Self::new()
    }
}
