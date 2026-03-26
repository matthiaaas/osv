module vfs

const max_mounts = 4

@[noinit]
pub struct VirtualFileSystem {
pub mut:
	mounts [max_mounts]Mount
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

pub fn (v &VirtualFileSystem) find_mount(path string) ?(MountId, &Mount) {
	mut best_id := -1
	mut best_len := 0

	for i in 0 .. v.mounts.len {
		mut mount := &v.mounts[i]
		if mount.active && path.starts_with(mount.prefix) && mount.prefix.len > best_len {
			best_id = i
			best_len = mount.prefix.len
		}
	}

	return MountId(u8(best_id)), unsafe { &v.mounts[best_id] }
}

pub fn (v &VirtualFileSystem) resolve(path string) !VNode {
	mount_id, mount := v.find_mount(path) or { return error('No mount found for path') }

	return error('Not implemented')
}

pub interface FileSystem {
	root() !VNode
	format() !
}

pub interface VNode {
	read_at(buf voidptr, len u32, offset u32) !
}
