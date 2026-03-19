use std::fmt;

pub struct Hexdump<'a> {
    data: &'a [u8],
    start_addr: u32,
}

impl<'a> Hexdump<'a> {
    pub fn new(data: &'a [u8], start_addr: Option<u32>) -> Self {
        Self {
            data,
            start_addr: start_addr.unwrap_or(0),
        }
    }
}

impl<'a> fmt::Display for Hexdump<'a> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        for (i, chunk) in self.data.chunks(16).enumerate() {
            let current_addr = self.start_addr.wrapping_add((i * 16) as u32);
            write!(f, "{:08X}  ", current_addr)?;

            for &byte in chunk {
                write!(f, "{:02X} ", byte)?;
            }

            if chunk.len() < 16 {
                let padding = 16 - chunk.len();
                for _ in 0..padding {
                    write!(f, "   ")?;
                }
            }

            write!(f, " |")?;

            for &byte in chunk {
                let ch = if byte.is_ascii_graphic() || byte == b' ' {
                    byte as char
                } else {
                    '.'
                };
                write!(f, "{}", ch)?;
            }

            writeln!(f, "|")?;
        }
        Ok(())
    }
}
