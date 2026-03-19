use crate::{
    devices::BusError,
    isa::{Instr, PrivilegeMode},
};
use core::fmt;

#[derive(Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Exception {
    IllegalInstruction(Instr),
    LoadAccessFault(u32),
    StoreAccessFault(u32),
    EnvironmentCall(PrivilegeMode),
}

// enum Interrupt {
// }

#[derive(Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Trap {
    Exception(Exception),
}

impl Trap {
    pub fn cause_code(&self) -> u8 {
        match self {
            Trap::Exception(exception) => match exception {
                Exception::IllegalInstruction(_) => 2,
                Exception::LoadAccessFault(_) => 5,
                Exception::StoreAccessFault(_) => 7,
                Exception::EnvironmentCall(priv_mode) => *priv_mode as u8 + 8,
            },
        }
    }

    pub fn value(&self) -> u32 {
        match self {
            Trap::Exception(exception) => match exception {
                Exception::IllegalInstruction(instr) => instr.word(),
                Exception::LoadAccessFault(addr) => *addr,
                Exception::StoreAccessFault(addr) => *addr,
                Exception::EnvironmentCall(_) => 0,
            },
        }
    }
}

impl fmt::Debug for Trap {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Trap::Exception(exception) => match exception {
                Exception::IllegalInstruction(instr) => {
                    write!(f, "IllegalInstruction {{ word: {:#010x} }}", instr.word())
                }
                Exception::LoadAccessFault(addr) => {
                    write!(f, "LoadAccessFault {{ addr: {:#010x} }}", addr)
                }
                Exception::StoreAccessFault(addr) => {
                    write!(f, "StoreAccessFault {{ addr: {:#010x} }}", addr)
                }
                Exception::EnvironmentCall(priv_mode) => {
                    f.debug_tuple("EnvironmentCall").field(priv_mode).finish()
                }
            },
        }
    }
}

impl From<BusError> for Trap {
    fn from(err: BusError) -> Self {
        match err {
            BusError::LoadAccessFault(addr) => Trap::Exception(Exception::LoadAccessFault(addr)),
            BusError::StoreAccessFault(addr) => Trap::Exception(Exception::StoreAccessFault(addr)),
        }
    }
}
