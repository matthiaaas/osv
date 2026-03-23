// https://gemini.google.com/app/f32c6f0f21066d0f

// REMOVABLE
module vfs

pub interface A__Inode {
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

pub interface A__File {
	read(buf u32, length u32) !
	write(buf u32, data []u8) !
	seek(offset u32, whence u32) !u32
	close() !
}

// pub struct OpenFile /* satisfies File */ {
// 	inode Inode
// 	position u32
// 	flags u32
// }

// pub fn (open_file OpenFile) read(length u32) !u32 {
// 	return open_file.inode.read()
// }

// pub struct Pipe /* satisfies File */ {
// 	buffer     [4096]u8
//     read_pos u32
// 	write_pos u32
// }

// pub struct Kernel {
// 	// ...

// mut:
// 	global_files [64]File
// }

pub type A__GlobalFileTableIndex = u32
