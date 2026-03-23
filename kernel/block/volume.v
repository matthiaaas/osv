module block

pub interface Volume {
	sector_count() u32
	sector_size() u32
	read(sector u32, mut buf [512]u8) !
	write(sector u32, mut buf [512]u8) !
}
