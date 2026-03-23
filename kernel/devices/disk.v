module devices

pub const disk0_base = u32(0x1000_1000)
pub const disk0_size = u32(0x1000)

pub const disk0_sector_size = u32(512)

const reg_ctrl = disk0_base + 0x00
const reg_sector = disk0_base + 0x04
const reg_data = disk0_base + 0x08
const reg_status = disk0_base + 0x0c

fn mmio_read_u32(addr u32) u32 {
	unsafe {
		volatile ptr := &u32(addr)
		return *ptr
	}
}
fn mmio_write_u32(addr u32, val u32) {
	unsafe {
		volatile ptr := &u32(addr)
		*ptr = val
	}
}

pub struct Disk {}

pub fn (disk Disk) sector_count() u32 {
	return u32(disk0_size / disk0_sector_size)
}

pub fn (disk Disk) sector_size() u32 {
	return u32(disk0_sector_size)
}

pub fn (disk Disk) read(sector u32, mut buf [512]u8) ! {
    assert buf.len >= disk0_sector_size

    mmio_write_u32(reg_sector, sector)
    mmio_write_u32(reg_ctrl, 1)

    for i in 0 .. disk0_sector_size {
        buf[i] = u8(mmio_read_u32(reg_data))
    }
}

pub fn (disk Disk) write(sector u32, mut buf [512]u8) ! {
    assert buf.len >= disk0_sector_size

    mmio_write_u32(reg_sector, sector)

    for i in 0 .. disk0_sector_size {
        mmio_write_u32(reg_data, buf[i])
    }

    mmio_write_u32(reg_ctrl, 2)
}
