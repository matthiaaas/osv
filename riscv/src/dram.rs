use crate::bus::{BusError, Device};

pub struct Dram {
    mem: Vec<u8>,
}

impl Dram {
    pub fn new(size: u32) -> Self {
        Self {
            mem: vec![0; size as usize],
        }
    }

    pub fn flash(&mut self, data: &[u8], offset: usize) -> Result<(), ()> {
        let end = offset + data.len();
        if end > self.mem.len() {
            return Err(());
        }

        self.mem[offset..end].copy_from_slice(data);
        Ok(())
    }
}

impl Device for Dram {
    fn name(&self) -> &str {
        "DRAM"
    }

    fn load(&mut self, addr: u32, size: u8) -> Result<u32, BusError> {
        assert!((addr as usize) + (size as usize) <= self.mem.len());

        let mut val: u32 = 0;
        for i in 0..size {
            val |= (self.mem[(addr as usize) + (i as usize)] as u32) << (i * 8);
        }
        Ok(val)
    }

    fn store(&mut self, addr: u32, size: u8, val: u32) -> Result<(), BusError> {
        assert!((addr as usize) + (size as usize) <= self.mem.len());

        for i in 0..size {
            self.mem[(addr as usize) + (i as usize)] = ((val >> (i * 8)) & 0xFF) as u8;
        }
        Ok(())
    }

    fn size(&self) -> u32 {
        self.mem.len() as u32
    }
}
