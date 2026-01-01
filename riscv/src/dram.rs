use crate::bus::{BusError, Device};

pub struct Dram {
    mem: Vec<u8>,
}

impl Dram {
    pub fn new(size: u32) -> Self {
        Self {
            mem: vec![0; size as usize], // TODO: btreemap
        }
    }

    pub fn flash(&mut self, addr: u32, data: &[u8]) -> Result<(), ()> {
        let start = addr as usize;
        let end = start + data.len();

        if end > self.mem.len() {
            return Err(());
        }

        self.mem[start..end].copy_from_slice(data);
        Ok(())
    }
}

impl Device for Dram {
    fn name(&self) -> &str {
        "DRAM"
    }

    fn load(&mut self, addr: u32, size: u8) -> Result<u32, BusError> {
        let start = addr as usize;
        let len = size as usize;

        if start + len > self.mem.len() {
            return Err(BusError::LoadAccessFault(addr));
        }

        let slice = &self.mem[start..start + len];

        let val = match len {
            1 => slice[0] as u32,
            2 => u16::from_le_bytes(slice.try_into().unwrap()) as u32,
            4 => u32::from_le_bytes(slice.try_into().unwrap()),
            _ => return Err(BusError::LoadAccessFault(addr)),
        };

        Ok(val)
    }

    fn store(&mut self, addr: u32, size: u8, val: u32) -> Result<(), BusError> {
        let start = addr as usize;
        let len = size as usize;

        if start + len > self.mem.len() {
            return Err(BusError::StoreAccessFault(addr));
        }

        let bytes = val.to_le_bytes();

        self.mem[start..start + len].copy_from_slice(&bytes[0..len]);

        Ok(())
    }

    fn size(&self) -> u32 {
        self.mem.len() as u32
    }
}
