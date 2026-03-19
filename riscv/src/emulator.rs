use crate::devices::Dram;

pub struct Emulator<'a> {
    kernel_path: &'a str,
    dram: Dram,
}
