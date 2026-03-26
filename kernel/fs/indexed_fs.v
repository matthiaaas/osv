module fs

import block { BlockDevice }

const fs_magic = u32(0x4f53_5646) // FSV0

const superblock_sector = u32(0)
const inode_bitmap_sector = u32(1)
const data_bitmap_sector = u32(2)
const inode_table_start_sector = u32(3)
const inode_table_sector_count = u32(32)
const data_region_start_sector = inode_table_start_sector + inode_table_sector_count

const name_max_bytes = 16

const direct_block_count = 12

struct Superblock {
	magic            u32
	total_sectors    u32
	inode_count      u32
	data_block_count u32
}

@[noinit]
pub struct IndexedFileSystem {
	volume BlockDevice
}

pub fn IndexedFileSystem.new(volume BlockDevice) IndexedFileSystem {
	return IndexedFileSystem{
		volume: BlockDevice
	}
}

pub fn (fs IndexedFileSystem) root() !Vnode {
	return error("Not implemented")
}

type Buffer = [512]u8

pub fn (fs IndexedFileSystem) format() ! {
	superblock := Superblock{
		magic:            fs_magic
		total_sectors:    fs.volume.sector_count()
		inode_count:      inode_table_sector_count * (fs.volume.sector_size() / sizeof(Inode))
		data_block_count: fs.volume.sector_count() - data_region_start_sector
	}
	fs.store(superblock_sector, &superblock)!

	restored_superblock := fs.load[Superblock](superblock_sector)!
	unsafe { restored_superblock.free() }

	kernel.uart0.puts('Superblock: ${restored_superblock}')
}

fn (fs IndexedFileSystem) store[T](sector u32, data &T) ! {
	mut buf := Buffer{}
	unsafe { vmemcpy(&buf, data, sizeof(T)) }
	fs.volume.write(sector, mut buf)!
}

fn (fs IndexedFileSystem) load[T](sector u32) !T {
	mut buf := Buffer{}
	fs.volume.read(sector, mut buf)!
	return unsafe { *(&T(&buf)) }
}
