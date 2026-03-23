use crate::devices::{BusError, Device};
use std::fs::File;
use std::io::{Read, Seek, SeekFrom, Write};

const SECTOR_SIZE: usize = 512;

const REG_CTRL: u32 = 0x00; // Write: 1 = load sector into buffer, 2 = flush buffer to disk
const REG_SECTOR: u32 = 0x04; // R/W: LBA sector index to operate on
const REG_DATA: u32 = 0x08; // R/W: sequential data port (auto-advances each access)
const REG_STATUS: u32 = 0x0C; // Read: 0 = ready (extend for busy/error flags later)

pub struct Disk {
    file: File,
    sector: u32,
    buffer: [u8; SECTOR_SIZE],
    data_ptr: usize,
}

impl Disk {
    pub fn new(path: &str) -> std::io::Result<Self> {
        let file = File::options()
            .read(true)
            .write(true)
            .create(true)
            .open(path)?;

        Ok(Self {
            file,
            sector: 0,
            buffer: [0; SECTOR_SIZE],
            data_ptr: 0,
        })
    }

    fn read(&mut self) {
        let offset = self.sector as u64 * SECTOR_SIZE as u64;
        if self.file.seek(SeekFrom::Start(offset)).is_ok() {
            let _ = self.file.read(&mut self.buffer);
        }
        self.data_ptr = 0;
    }

    fn write(&mut self) {
        let offset = self.sector as u64 * SECTOR_SIZE as u64;
        if self.file.seek(SeekFrom::Start(offset)).is_ok() {
            let _ = self.file.write_all(&self.buffer);
        }
        self.data_ptr = 0;
    }
}

impl Device for Disk {
    fn name(&self) -> &str {
        "Disk"
    }

    fn load(&mut self, addr: u32, _size: u8) -> Result<u32, BusError> {
        match addr {
            REG_SECTOR => Ok(self.sector),
            REG_STATUS => Ok(0), // always ready for simplicity,
            REG_DATA => {
                if self.data_ptr < SECTOR_SIZE {
                    let val = self.buffer[self.data_ptr] as u32;
                    self.data_ptr += 1;
                    Ok(val)
                } else {
                    Ok(0)
                }
            }
            _ => Err(BusError::LoadAccessFault(addr)),
        }
    }

    fn store(&mut self, addr: u32, _size: u8, val: u32) -> Result<(), BusError> {
        match addr {
            REG_CTRL => {
                match val {
                    1 => self.read(),
                    2 => self.write(),
                    _ => {}
                }
                Ok(())
            }
            REG_SECTOR => {
                self.sector = val;
                self.data_ptr = 0;
                Ok(())
            }
            REG_DATA => {
                if self.data_ptr < SECTOR_SIZE {
                    self.buffer[self.data_ptr] = val as u8;
                    self.data_ptr += 1;
                }
                Ok(())
            }
            _ => Err(BusError::StoreAccessFault(addr)),
        }
    }

    fn size(&self) -> u32 {
        0x1000
    }
}
