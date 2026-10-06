#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(transparent)]
pub struct Pte(pub u32);

impl Pte {
    #[inline(always)]
    pub fn is_valid(self) -> bool {
        (self.0 & 0x1) != 0
    }

    #[inline(always)]
    pub fn is_readable(self) -> bool {
        (self.0 & 0x2) != 0
    }

    #[inline(always)]
    pub fn is_writable(self) -> bool {
        (self.0 & 0x4) != 0
    }

    #[inline(always)]
    pub fn is_executable(self) -> bool {
        (self.0 & 0x8) != 0
    }

    #[inline(always)]
    pub fn is_user(self) -> bool {
        (self.0 & 0x10) != 0
    }

    #[inline(always)]
    pub fn is_leaf(self) -> bool {
        self.is_readable() || self.is_writable() || self.is_executable()
    }

    #[inline(always)]
    pub fn ppn(self) -> u32 {
        (self.0 >> 10) & 0x003f_ffff
    }
}

impl From<u32> for Pte {
    fn from(value: u32) -> Self {
        Self(value)
    }
}
