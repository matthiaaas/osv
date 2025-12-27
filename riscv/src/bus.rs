#[derive(Debug)]
pub enum BusError {
    LoadAccessFault(u32),
    StoreAccessFault(u32),
}

pub trait Device {
    fn name(&self) -> &str;

    fn load(&mut self, addr: u32, size: u8) -> Result<u32, BusError>;

    fn store(&mut self, addr: u32, size: u8, val: u32) -> Result<(), BusError>;

    fn size(&self) -> u32;
}

struct MappedDevice {
    base_addr: u32,
    device: Box<dyn Device>,
}

pub struct Bus {
    mappings: Vec<MappedDevice>,
}

impl Bus {
    pub fn new() -> Self {
        Self {
            mappings: Vec::new(),
        }
    }

    pub fn map_to(&mut self, base_addr: u32, device: Box<dyn Device>) {
        self.mappings.push(MappedDevice { base_addr, device });
    }

    pub fn load(&mut self, addr: u32, size: u8) -> Result<u32, BusError> {
        match self.probe(addr) {
            Ok(mapping) => mapping.device.load(addr - mapping.base_addr, size),
            Err(()) => Err(BusError::LoadAccessFault(addr)),
        }
    }

    pub fn store(&mut self, addr: u32, size: u8, val: u32) -> Result<(), BusError> {
        match self.probe(addr) {
            Ok(mapping) => mapping.device.store(addr - mapping.base_addr, size, val),
            Err(()) => Err(BusError::StoreAccessFault(addr)),
        }
    }

    fn probe(&mut self, addr: u32) -> Result<&mut MappedDevice, ()> {
        for mapping in &mut self.mappings {
            if addr >= mapping.base_addr && addr <= mapping.base_addr + mapping.device.size() {
                return Ok(mapping);
            }
        }
        Err(())
    }
}
