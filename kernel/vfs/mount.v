module vfs

type MountId = u8

@[noinit]
pub struct Mount {
pub mut:
	active bool
	prefix string
	fs     FileSystem
}

pub fn Mount.new(prefix string, fs FileSystem) Mount {
	return Mount{
		prefix: prefix
		fs:     fs
		active: true
	}
}
