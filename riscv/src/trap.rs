use crate::{
    devices::BusError,
    isa::{Instr, PrivilegeMode},
    mmu::PageFault,
};
use core::fmt;

#[derive(Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Exception {
    IllegalInstruction(Instr),
    LoadAccessFault(u32),
    StoreAccessFault(u32),
    EnvironmentCall(PrivilegeMode),
    InstructionPageFault(u32),
    LoadPageFault(u32),
    StorePageFault(u32),
}

impl Exception {
    pub fn cause_code(&self) -> u8 {
        use Exception::*;
        match self {
            IllegalInstruction(_) => 2,
            LoadAccessFault(_) => 5,
            StoreAccessFault(_) => 7,
            EnvironmentCall(priv_mode) => *priv_mode as u8 + 8,
            InstructionPageFault(_) => 12,
            LoadPageFault(_) => 13,
            StorePageFault(_) => 15,
        }
    }

    pub fn value(&self) -> u32 {
        use Exception::*;
        match self {
            IllegalInstruction(instr) => instr.word(),
            EnvironmentCall(_) => 0,
            LoadAccessFault(addr)
            | StoreAccessFault(addr)
            | InstructionPageFault(addr)
            | LoadPageFault(addr)
            | StorePageFault(addr) => *addr,
        }
    }
}

impl fmt::Debug for Exception {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        use Exception::*;
        match self {
            IllegalInstruction(instr) => f
                .debug_struct("IllegalInstruction")
                .field("word", &format_args!("{:#010x}", instr.word()))
                .finish(),
            EnvironmentCall(priv_mode) => {
                f.debug_tuple("EnvironmentCall").field(priv_mode).finish()
            }
            _ => {
                let (name, addr) = match self {
                    LoadAccessFault(addr) => ("LoadAccessFault", addr),
                    StoreAccessFault(addr) => ("StoreAccessFault", addr),
                    InstructionPageFault(addr) => ("InstructionPageFault", addr),
                    LoadPageFault(addr) => ("LoadPageFault", addr),
                    StorePageFault(addr) => ("StorePageFault", addr),
                    _ => unreachable!(),
                };
                f.debug_struct(name)
                    .field("addr", &format_args!("{:#010x}", addr))
                    .finish()
            }
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[repr(u8)]
pub enum Trap {
    Exception(Exception),
    // Interrupt(Interrupt),
}

impl Trap {
    pub fn cause_code(&self) -> u8 {
        match self {
            Self::Exception(e) => e.cause_code(),
            // Self::Interrupt(i) => i.cause_code(),
        }
    }

    pub fn value(&self) -> u32 {
        match self {
            Self::Exception(e) => e.value(),
            // Self::Interrupt(i) => i.value(),
        }
    }
}

impl From<BusError> for Trap {
    fn from(err: BusError) -> Self {
        use Exception::*;
        let exception = match err {
            BusError::LoadAccessFault(addr) => LoadAccessFault(addr),
            BusError::StoreAccessFault(addr) => StoreAccessFault(addr),
        };
        Self::Exception(exception)
    }
}

impl From<PageFault> for Trap {
    fn from(fault: PageFault) -> Self {
        use Exception::*;
        let exception = match fault {
            PageFault::InstructionPageFault(addr) => InstructionPageFault(addr),
            PageFault::LoadPageFault(addr) => LoadPageFault(addr),
            PageFault::StorePageFault(addr) => StorePageFault(addr),
        };
        Self::Exception(exception)
    }
}
