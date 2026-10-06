use crate::isa::{PrivilegeMode, Pte};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PageFault {
    InstructionPageFault(u32),
    LoadPageFault(u32),
    StorePageFault(u32),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum AccessType {
    Fetch,
    Load,
    Store,
}

impl AccessType {
    pub fn page_fault(self, virt_addr: u32) -> PageFault {
        match self {
            AccessType::Fetch => PageFault::InstructionPageFault(virt_addr),
            AccessType::Load => PageFault::LoadPageFault(virt_addr),
            AccessType::Store => PageFault::StorePageFault(virt_addr),
        }
    }

    pub fn grants(self, pte: Pte, mode: PrivilegeMode) -> bool {
        if mode == PrivilegeMode::User && !pte.is_user() {
            return false;
        }

        match self {
            AccessType::Fetch => pte.is_executable(),
            AccessType::Load => pte.is_readable(),
            AccessType::Store => pte.is_writable(),
        }
    }
}
