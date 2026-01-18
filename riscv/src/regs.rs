use std::fmt;

const NUM_REGS: usize = 32;

pub const ABI_REG_NAMES: [&str; NUM_REGS] = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1", "a2", "a3", "a4",
    "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4",
    "t5", "t6",
];

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

impl Default for RegFile {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Debug for RegFile {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut ds = f.debug_struct("RegFile");
        for (i, &reg) in self.regs.iter().enumerate() {
            if reg != 0 {
                ds.field(
                    &format!("x{}({})", i, ABI_REG_NAMES[i]),
                    &format_args!("{:#010x}", reg),
                );
            }
        }
        ds.finish()
    }
}
