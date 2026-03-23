module vfs

import block { Volume }

const fs_magic = u32(0x4f53_5646) // FSV0

const volume_name_max_bytes = 16

const direct_block_count = 12

struct Superblock {
	total_sectors    u32
	inode_count      u32
	data_block_count u32
}

enum FileType as u8 {
	file
	directory
}

struct Inode {
	file_type  FileType
	size       u32
	link_count u32
	direct     [direct_block_count]u32
	indirect   u32
}

struct DirectoryEntry {
	inode_number u32
	name_bytes   [volume_name_max_bytes]u8
}

@[noinit]
pub struct IndexedFileSystem {
pub mut:
	volume Volume
}

pub fn IndexedFileSystem.new(volume Volume) IndexedFileSystem {
	return IndexedFileSystem{
		volume: volume
	}
}

pub fn (fs IndexedFileSystem) root() {
}

pub fn (fs IndexedFileSystem) format() ! {
    mut buf := [512]u8{}
    buf[0] = u8(4)
    fs.volume.write(0, mut buf)!
    fs.volume.read(0, mut buf)!

	superblock := Superblock{

	}
}

fn (fs IndexedFileSystem) store() {
}
