module block

@[noinit]
pub struct BlockIo {
	device     BlockDevice
	block_size u32
}

pub fn BlockIo.new(device BlockDevice, block_size u32) BlockIo {
	return BlockIo{
		device:     device
		block_size: block_size
	}
}

pub fn (bio &BlockIo) read(block_idx u32, mut buf []u8) ! {
	sector_size := bio.device.sector_size()
	sectors_per_block := bio.block_size / sector_size
	start_sector := block_idx * sectors_per_block
	number_of_sectors := u32(buf.len) / sector_size

	for i in 0 .. number_of_sectors {
		start := i * sector_size
		end := (i + 1) * sector_size

		bio.device.read(start_sector + i, mut buf[start..end])!
	}
}

pub fn (bio &BlockIo) write(block_idx u32, buf []u8) ! {
	sector_size := bio.device.sector_size()
	sectors_per_block := bio.block_size / sector_size
	start_sector := block_idx * sectors_per_block
	number_of_sectors := u32(buf.len) / sector_size

	for i in 0 .. number_of_sectors {
		start := i * sector_size
		end := (i + 1) * sector_size
		bio.device.write(start_sector + i, buf[start..end])!
	}
}
