pub interface Inode {
	number()
	mode()
	size()
	link_count()

	read()
	write()

	lookup()
	create()
	unlink()
}

pub interface File {
	read(buf u32, length u32) !
	write(buf u32, data []u8) !
	seek(offset u32, whence u32) !u32
	close() !
}

pub struct OpenFile /* satisfies File */ {
	inode Inode
	pos u32
	flags u32
}

pub fn (open_file OpenFile) read(length u32) !u32 {
	return open_file.inode.read()
}

pub struct Pipe /* satisfies File */ {
	buffer     [4096]u8
    read_pos u32
	write_pos u32
}

// pub struct Process {
// pub:
// 	pid u32
// mut:
// 	...
// 	file_descriptors []File
// }
