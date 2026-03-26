module block

// @[noinit]
// pub struct BlockIo {
// 	device BlockDevice
// 	block_size u32
// }

// pub fn BlockIo.new(device BlockDevice, block_size u32) BlockIo {
// 	return BlockIo{
// 		device: device,
// 		block_size: block_size
// 	}
// }

// pub fn (bio BlockIo) read(block u32, mut buf []byte, len u32) ! {
// 	sectors_per_block := bio.block_size / bio.device.sector_size()
// 	start_sector := block * sectors_per_block

// 	for i in 0 .. sectors_per_block * len {
// 		buf << bio.device.read(start_sector + i)!
// 	}
// }
