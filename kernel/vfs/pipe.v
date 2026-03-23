module vfs

pub struct Pipe {
pub mut:
	read_pos  u32
	write_pos u32
	buffer    [4096]u8
}

pub fn Pipe.new() Pipe {
	return Pipe{
		read_pos:  0
		write_pos: 0
	}
}
