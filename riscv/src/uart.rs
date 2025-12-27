use crate::bus::{BusError, Device};
use std::io::{self, Write};

pub struct Uart {}

impl Uart {
    pub fn new() -> Self {
        Self {}
    }
}

impl Device for Uart {
    fn name(&self) -> &str {
        "UART"
    }

    fn load(&mut self, _addr: u32, _size: u8) -> Result<u32, BusError> {
        Ok(0)
    }

    fn store(&mut self, _addr: u32, _size: u8, val: u32) -> Result<(), BusError> {
        print!("{}", val as u8 as char);
        io::stdout().flush().unwrap();
        Ok(())
    }

    fn size(&self) -> u32 {
        0x1000
    }
}
