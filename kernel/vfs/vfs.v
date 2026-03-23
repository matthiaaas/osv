module vfs

pub const max_mounts = 8
pub const max_entries = 64

type MountId = u8

@[noinit]
pub struct VirtualFileSystem {
pub mut:
	mounts [max_mounts]Mount
	// files  [max_entries]OpenFile
}

pub fn (mut v VirtualFileSystem) mount(prefix string, fs FileSystem) !MountId {
	for i in 0 .. v.mounts.len {
		if !v.mounts[i].active {
			v.mounts[i] = Mount.new(prefix, fs)
			return MountId(u8(i))
		}
	}
	return error('No free mount slot')
}

pub fn (v &VirtualFileSystem) resolve(path string) ?(MountId, &Mount) {
	mut best_id := -1
	mut best_len := 0

	for i in 0 .. v.mounts.len {
		mut mount := unsafe { &v.mounts[i] }
		if mount.active && path.starts_with(mount.prefix) && mount.prefix.len > best_len {
			best_id = i
			best_len = mount.prefix.len
		}
	}

	return MountId(u8(best_id)), unsafe { &v.mounts[best_id] }
}

pub fn (v &VirtualFileSystem) walk(path string) ! {}

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

pub interface FileSystem {
	root()
    format() !
}

pub interface OpenFile {
}
