#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum PrivilegeMode {
    _User = 0b00,
    _Supervisor = 0b01,
    Machine = 0b11,
}
