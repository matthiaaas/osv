#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum PrivilegeMode {
    _User = 0b00,
    _Supervisor = 0b01,
    Machine = 0b11,
}

impl From<u8> for PrivilegeMode {
    fn from(value: u8) -> Self {
        match value {
            0b00 => PrivilegeMode::_User,
            0b01 => PrivilegeMode::_Supervisor,
            0b11 => PrivilegeMode::Machine,
            _ => panic!("Invalid privilege mode value: {}", value),
        }
    }
}
