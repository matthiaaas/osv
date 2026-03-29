module vfs

const max_mounts = 4

@[noinit]
pub struct VirtualFileSystem {
pub mut:
	public_mounts [max_mounts]Mount
}

pub fn (mut v VirtualFileSystem) mount(prefix string, fs FileSystem) !MountId {
	for i in 0 .. v.public_mounts.len {
		if !v.public_mounts[i].active {
			v.public_mounts[i] = Mount.new(prefix, fs)
			return MountId(u8(i))
		}
	}
	return error('No free mount slot')
}

fn (v &VirtualFileSystem) find_mount(path string) ?(MountId, &Mount) {
	mut best_id := -1
	mut best_len := 0

	for i in 0 .. v.public_mounts.len {
		mut mount := &v.public_mounts[i]
		if mount.active && path.starts_with(mount.prefix) && mount.prefix.len > best_len {
			best_id = i
			best_len = mount.prefix.len
		}
	}

	if best_id == -1 {
		return none
	}

	return MountId(u8(best_id)), unsafe { &v.public_mounts[best_id] }
}

pub fn (v &VirtualFileSystem) resolve(path string) !VNode {
	mount_id, mount := v.find_mount(path) or { return error('No mount found for path') }
	path_traversal := PathTraversal.from(path.replace_once(mount.prefix, ''))
	mut curr_vnode := mount.fs.root()!

	for segment in path_traversal {
		if !curr_vnode.is_directory() {
			return error('Not a directory')
		}
		curr_vnode = curr_vnode.lookup(segment)!
	}

	return curr_vnode
}

pub interface FileSystem {
	root() !VNode
}

pub interface VNode {
	is_directory() bool
	lookup(name string) !VNode
	read_at(buf voidptr, len u32, offset u32) !
	mut: write_at(buf voidptr, len u32, offset u32) !
	create(name string, is_directory bool) !VNode
}
