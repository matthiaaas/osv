use std::fmt;

const NUM_REGS: usize = 32;

pub struct RegFile {
    regs: [u32; NUM_REGS],
}

impl RegFile {
    pub fn new() -> Self {
        Self {
            regs: [0; NUM_REGS],
        }
    }

    pub fn read(&self, idx: u8) -> u32 {
        self.regs[idx as usize]
    }

    pub fn write(&mut self, idx: u8, val: u32) {
        if idx != 0 {
            self.regs[idx as usize] = val;
        }
    }
}

impl fmt::Debug for RegFile {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let non_zero: Vec<_> = self
            .regs
            .iter()
            .enumerate()
            .filter(|(_, val)| **val != 0)
            .map(|(i, val)| format!("x{:02}:0x{:08x}", i, val))
            .collect();
        write!(f, "{}", non_zero.join(" "))
    }
}
