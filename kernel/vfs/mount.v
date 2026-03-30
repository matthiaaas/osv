module vfs

type MountId = u8

@[noinit]
struct Mount {
pub mut:
	active bool
	prefix string
	fs     FileSystem
}

fn Mount.new(prefix string, fs FileSystem) Mount {
	return Mount{
		prefix: prefix
		fs:     fs
		active: true
	}
}
