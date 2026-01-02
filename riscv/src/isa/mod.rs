pub mod formats;
pub mod opcodes;
pub mod priv_mode;

pub use formats::*;
pub use priv_mode::*;

pub const INSTRUCTION_SIZE: u8 = 4;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct Instr(pub u32);

impl Instr {
    #[inline(always)]
    pub fn new(word: u32) -> Self {
        Self(word)
    }

    #[inline(always)]
    pub fn word(&self) -> u32 {
        self.0
    }

    #[inline(always)]
    pub fn opcode(&self) -> u8 {
        (self.word() & 0x7F) as u8
    }

    #[inline(always)]
    pub fn funct3(&self) -> u8 {
        ((self.word() >> 12) & 0x07) as u8
    }

    #[inline(always)]
    pub fn funct7(&self) -> u8 {
        ((self.word() >> 25) & 0x7F) as u8
    }

    pub fn as_i_type(&self) -> IType {
        IType(*self)
    }

    pub fn as_r_type(&self) -> RType {
        RType(*self)
    }

    pub fn as_u_type(&self) -> UType {
        UType(*self)
    }

    pub fn as_j_type(&self) -> JType {
        JType(*self)
    }

    pub fn as_s_type(&self) -> SType {
        SType(*self)
    }
}

impl From<u32> for Instr {
    fn from(word: u32) -> Self {
        Self(word)
    }
}
