use super::Instr;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct IType(pub(super) Instr);

impl IType {
    #[inline(always)]
    pub fn rd(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 7) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn rs1(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 15) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn imm(&self) -> i32 {
        let raw = (self.0).0;
        (raw as i32) >> 20
    }
}
