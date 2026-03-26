module block

pub interface BlockDevice {
	sector_count() u32
	sector_size() u32
	read(sector u32, mut buf []byte) !
	write(sector u32, mut buf []byte) !
}
