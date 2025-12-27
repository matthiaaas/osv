use crate::{bus::BusError, isa::Instr};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Trap {
    IllegalInstruction(Instr) = 3,
    LoadAccessFault(u32) = 5,
    StoreAccessFault(u32) = 7,
}

impl From<BusError> for Trap {
    fn from(err: BusError) -> Self {
        match err {
            BusError::LoadAccessFault(addr) => Trap::LoadAccessFault(addr),
            BusError::StoreAccessFault(addr) => Trap::StoreAccessFault(addr),
        }
    }
}
