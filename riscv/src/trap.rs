use crate::{
    bus::BusError,
    isa::{Instr, PrivilegeMode},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Trap {
    IllegalInstruction(Instr),
    LoadAccessFault(u32),
    StoreAccessFault(u32),
    EnvironmentCall(PrivilegeMode),
}

impl Trap {
    pub fn cause_code(&self) -> u8 {
        match self {
            Trap::IllegalInstruction(_) => 2,
            Trap::LoadAccessFault(_) => 5,
            Trap::StoreAccessFault(_) => 7,
            Trap::EnvironmentCall(priv_mode) => *priv_mode as u8 + 8,
        }
    }

    pub fn value(&self) -> u32 {
        match self {
            Trap::IllegalInstruction(instr) => instr.word(),
            Trap::LoadAccessFault(addr) => *addr,
            Trap::StoreAccessFault(addr) => *addr,
            Trap::EnvironmentCall(_) => 0,
        }
    }
}

impl From<BusError> for Trap {
    fn from(err: BusError) -> Self {
        match err {
            BusError::LoadAccessFault(addr) => Trap::LoadAccessFault(addr),
            BusError::StoreAccessFault(addr) => Trap::StoreAccessFault(addr),
        }
    }
}
