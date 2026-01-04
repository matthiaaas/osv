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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct RType(pub(super) Instr);

impl RType {
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
    pub fn rs2(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 20) & 0x1f) as u8
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct JType(pub(super) Instr);

impl JType {
    #[inline(always)]
    pub fn rd(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 7) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn imm(&self) -> i32 {
        let raw = (self.0).0;

        let imm_20 = ((raw >> 31) & 0x1) << 20;
        let imm_10_1 = ((raw >> 21) & 0x3ff) << 1;
        let imm_11 = ((raw >> 20) & 0x1) << 11;
        let imm_19_12 = ((raw >> 12) & 0xff) << 12;

        let imm = (imm_20 | imm_19_12 | imm_11 | imm_10_1) as i32;

        // sextend
        (imm << 11) >> 11
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct UType(pub(super) Instr);

impl UType {
    #[inline(always)]
    pub fn rd(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 7) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn imm(&self) -> i32 {
        let raw = (self.0).0;
        (raw & 0xfffff000) as i32
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct SType(pub(super) Instr);

impl SType {
    #[inline(always)]
    pub fn rs1(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 15) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn rs2(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 20) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn imm(&self) -> i32 {
        let raw = (self.0).0;

        let imm_4_0 = (raw >> 7) & 0x1f;
        let imm_11_5 = (raw >> 25) & 0x7f;

        let imm = (imm_11_5 << 5) | imm_4_0;

        // sextend
        ((imm as i32) << 12) >> 20
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct BType(pub(super) Instr);

impl BType {
    #[inline(always)]
    pub fn rs1(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 15) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn rs2(&self) -> u8 {
        let raw = (self.0).0;
        ((raw >> 20) & 0x1f) as u8
    }

    #[inline(always)]
    pub fn imm(&self) -> i32 {
        let raw = (self.0).0;

        let imm_12 = ((raw >> 31) & 0x1) << 12;
        let imm_10_5 = ((raw >> 25) & 0x3f) << 5;
        let imm_4_1 = ((raw >> 8) & 0xf) << 1;
        let imm_11 = ((raw >> 7) & 0x1) << 11;

        let imm = (imm_12 | imm_11 | imm_10_5 | imm_4_1) as i32;

        // sextend
        (imm << 19) >> 19
    }
}
