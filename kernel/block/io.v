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
	assert u32(buf.len) % sector_size == 0
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
	assert u32(buf.len) % sector_size == 0
	sectors_per_block := bio.block_size / sector_size
	start_sector := block_idx * sectors_per_block
	number_of_sectors := u32(buf.len) / sector_size

	for i in 0 .. number_of_sectors {
		start := i * sector_size
		end := (i + 1) * sector_size
		bio.device.write(start_sector + i, buf[start..end])!
	}
}

pub fn (bio &BlockIo) read_at(block_idx u32, offset u32, mut buf []u8) ! {
	assert offset < bio.block_size
	assert buf.len <= bio.block_size - offset

	mut block_buf := []u8{len: int(bio.block_size)}
	bio.read(block_idx, mut block_buf)!
	unsafe { vmemcpy(&buf[0], &block_buf[offset], buf.len) }
}

pub fn (bio &BlockIo) write_at(block_idx u32, offset u32, buf []u8) ! {
	assert offset < bio.block_size
	assert buf.len <= bio.block_size - offset

	mut block_buf := []u8{len: int(bio.block_size)}
	bio.read(block_idx, mut block_buf)!
	unsafe { vmemcpy(&block_buf[offset], &buf[0], buf.len) }
	bio.write(block_idx, block_buf)!
}
