module main

import vfs { VNode }

type SeekFrom = u32

@[noinit]
pub struct OpenFileDescription {
mut:
	vnode     VNode
	position  u32
	flags     u32
	ref_count u32
}

fn OpenFileDescription.new(vnode VNode, flags u32) OpenFileDescription {
	return OpenFileDescription{
		vnode:     vnode
		position:  0
		flags:     flags
		ref_count: 1
	}
}

pub fn (mut ofd OpenFileDescription) read(buf voidptr, len u32) ! {
	ofd.vnode.read_at(buf, len, ofd.position)!
	ofd.position += len
}

pub fn (mut ofd OpenFileDescription) write(buf voidptr, len u32) ! {
	ofd.vnode.write_at(buf, len, ofd.position)!
	ofd.position += len
}

pub fn (mut ofd OpenFileDescription) lseek(offset u32, whence SeekFrom) ! {
	ofd.position = offset
}

pub type OpenFileDescriptor = u8

const max_open_files = 16

@[noinit]
pub struct GlobalFileTable {
mut:
	open_files [max_open_files]OpenFileDescription
}

pub fn (gft &GlobalFileTable) at(index u32) ?&OpenFileDescription {
	assert index < max_open_files

	open_file := &gft.open_files[index]
	if open_file.ref_count == 0 {
		return none
	}
	return open_file
}

pub fn (mut gft GlobalFileTable) add(vnode VNode, flags u32) !OpenFileDescriptor {
	for i in 0 .. gft.open_files.len {
		if gft.open_files[i].ref_count == 0 {
			gft.open_files[i] = OpenFileDescription.new(vnode, flags)
			return OpenFileDescriptor(i)
		}
	}
	return error('No free open file slot')
}

pub fn (mut gft GlobalFileTable) close(index OpenFileDescriptor) ! {
	mut open_file := gft.at(index) or { return error('Open file not found') }
	open_file.ref_count--
	if open_file.ref_count == 0 {
		open_file.vnode.close()!
	}
}
