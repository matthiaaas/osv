module vfs

const max_open_files = 16

@[noinit]
pub struct OpenFileDescription {
pub:
	vnode    VNode
	position u32
	flags    u32
}

@[noinit]
pub struct GlobalFileTable {
	open_files [max_open_files]OpenFileDescription
}

pub fn (gft GlobalFileTable) at(index u32) OpenFileDescription {
	return gft.open_files[index]
}
