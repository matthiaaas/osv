module fs

import block { BlockDevice, BlockIo }
import vfs { FileSystem, VNode }
import ds { Bitmap }

const magic = 0x1234_5678
const block_size = 1024 // bytes
const inode_bitmap_location = 1
const data_bitmap_location = 2
const inode_table_location = 3
const inode_table_size = 16
const data_region_location = inode_table_location + inode_table_size

const root_inode_number = u32(0)

struct Superblock {
	magic                 u32
	block_size            u32
	block_count           u32
	inode_bitmap_location u32
	data_bitmap_location  u32
	inode_table_location  u32
	inode_table_size      u32
	data_region_location  u32
	data_region_size      u32
}

fn (superblock &Superblock) to_bytes() []u8 {
	mut buf := []u8{len: int(sizeof(Superblock))}
	unsafe { vmemcpy(&buf[0], superblock, sizeof(Superblock)) }
	return buf
}

fn Superblock.from_bytes(bytes []u8) !Superblock {
	superblock := Superblock{}
	unsafe { vmemcpy(&superblock, &bytes[0], sizeof(Superblock)) }
	if superblock.magic != magic {
		return error('Invalid superblock magic: ${superblock.magic}')
	}
	return superblock
}

const direct_block_count = 12
const file_type_mask = 0o170000
const file_type_directory = 0o040000

struct Inode {
	mode       u16
	size       u32
	link_count u32
	direct     [direct_block_count]u32
	indirect   u32
}

fn Inode.from_bytes(bytes []u8) !Inode {
	inode := Inode{}
	unsafe { vmemcpy(&inode, &bytes[0], sizeof(Inode)) }
	return inode
}

fn (inode &Inode) is_directory() bool {
	kernel.uart0.puts('inode.mode: ${inode.mode}\n')
	return inode.mode & file_type_mask == file_type_directory
}

fn (inode &Inode) to_bytes() []u8 {
	mut buf := []u8{len: int(sizeof(Inode))}
	unsafe { vmemcpy(&buf[0], inode, sizeof(Inode)) }
	return buf
}

const max_dir_name_bytes = 28

struct DirectoryEntry {
	inode_number u32
	name_bytes   [max_dir_name_bytes]u8
}

fn DirectoryEntry.from(inode_number u32, name string) DirectoryEntry {
	src := name.bytes()
	name_bytes := [max_dir_name_bytes]u8{}
	unsafe { vmemcpy(&name_bytes[0], &src[0], int_min(src.len, name_bytes.len)) }
	return DirectoryEntry{
		inode_number: inode_number
		name_bytes: name_bytes
	}
}

fn (de &DirectoryEntry) name() string {
	return unsafe { byteptr(de.name_bytes).vstring() }
}

const max_directory_block_entries = block_size / sizeof(DirectoryEntry)

struct DirectoryBlock {
mut:
	entries [max_directory_block_entries]DirectoryEntry
}

fn (mut db DirectoryBlock) add(entry DirectoryEntry) {
	for i in 0 .. db.entries.len {
		if db.entries[i].name() == '' {
			db.entries[i] = entry
			return
		}
	}
}

fn (db &DirectoryBlock) find(name string) ?&DirectoryEntry {
	for i in 0 .. db.entries.len {
		if db.entries[i].name() == name {
			return &db.entries[i]
		}
	}
	return none
}

fn (db &DirectoryBlock) to_bytes() []u8 {
	mut buf := []u8{len: int(sizeof(DirectoryBlock))}
	unsafe { vmemcpy(&buf[0], db, sizeof(DirectoryBlock)) }
	return buf
}

@[noinit]
pub struct IndexedFileSystem implements FileSystem {
	volume     BlockDevice
	bio        BlockIo
	superblock Superblock
mut:
	inode_bitmap Bitmap
	data_bitmap Bitmap
}

fn IndexedFileSystem.new(volume BlockDevice, superblock Superblock) !IndexedFileSystem {
	bio := BlockIo.new(volume, block_size)

	mut buf := []u8{len: int(block_size)}
	bio.read(superblock.inode_bitmap_location, mut buf)!
	inode_bitmap := Bitmap.new(buf)

	bio.read(superblock.data_bitmap_location, mut buf)!
	data_bitmap := Bitmap.new(buf)

	return IndexedFileSystem{
		volume:     volume
		bio:        bio
		superblock: superblock
		inode_bitmap: inode_bitmap
		data_bitmap: data_bitmap
	}
}

pub fn IndexedFileSystem.load(device BlockDevice) !IndexedFileSystem {
	mut buf := []u8{len: int(device.sector_size())}
	device.read(0, mut buf)!
	superblock := Superblock.from_bytes(buf)!
	kernel.uart0.puts('Superblock: ${superblock}')
	return IndexedFileSystem.new(device, superblock)!
}

pub fn IndexedFileSystem.format(device BlockDevice) !IndexedFileSystem {
	block_count := (device.sector_count() * device.sector_size()) / block_size
	superblock := Superblock{
		magic:                 magic
		block_size:            block_size
		block_count:           block_count
		inode_bitmap_location: inode_bitmap_location
		data_bitmap_location:  data_bitmap_location
		inode_table_location:  inode_table_location
		inode_table_size:      inode_table_size
		data_region_location:  data_region_location
		data_region_size:      block_count - data_region_location
	}
	device.write(0, superblock.to_bytes())!

	bio := BlockIo.new(device, block_size)

	mut inode_bitmap := Bitmap.new([]u8{len: block_size})
	inode_bitmap.set(root_inode_number)
	bio.write(superblock.inode_bitmap_location, inode_bitmap.bytes)!

	root_data_block_location := data_region_location + root_inode_number
	mut data_bitmap := Bitmap.new([]u8{len: block_size})
	data_bitmap.set(root_data_block_location)
	bio.write(superblock.data_bitmap_location, data_bitmap.bytes)!

	mut ifs := IndexedFileSystem.new(device, superblock)!

	mut dir_block := DirectoryBlock{}
	dir_block.add(DirectoryEntry.from(root_inode_number, '.'))
	dir_block.add(DirectoryEntry.from(root_inode_number, '..'))

	absolute_data_block_location := data_region_location + root_data_block_location
	bio.write(absolute_data_block_location, dir_block.to_bytes())!

	mut root_direct := [direct_block_count]u32{}
	root_direct[0] = root_data_block_location

	root_inode := Inode{
		mode: file_type_directory,
		size: sizeof(DirectoryBlock) * 2,
		link_count: 2,
		direct: root_direct,
		indirect: 0,
	}
	bio.write(inode_table_location + root_inode_number, root_inode.to_bytes())!
	kernel.uart0.puts('root_inode_bytes: ${root_inode.to_bytes()}\n')

	mut buf := []u8{len: int(sizeof(Inode))}
	bio.read(inode_table_location + root_inode_number, mut buf)!
	kernel.uart0.puts('buffff: ${buf}\n')

	return ifs
}

pub fn (ifs &IndexedFileSystem) root() !VNode {
	root_inode := ifs.read_inode(root_inode_number)!
	kernel.uart0.puts('root_inode: ${root_inode.size}\n')
	return IndexedVNode.new(ifs, root_inode_number, root_inode)
}

fn (ifs &IndexedFileSystem) read_inode(inode_number u32) !Inode {
	mut buf := []u8{len: int(sizeof(Inode))}
	ifs.bio.read(ifs.superblock.inode_table_location + inode_number, mut buf)!
	kernel.uart0.puts('buf: ${buf}\n')
	return Inode.from_bytes(buf)!
}

fn (mut ifs IndexedFileSystem) alloc_inode() !u32 {
	for i in 0 .. ifs.superblock.inode_table_size * ifs.superblock.block_size * 8 {
		if !ifs.inode_bitmap.is_set(i) {
			ifs.inode_bitmap.set(i)
			ifs.bio.write(ifs.superblock.inode_bitmap_location, ifs.inode_bitmap.bytes)!
			return i
		}
	}
	return error('No free inodes')
}

struct IndexedVNode implements VNode {
	ifs IndexedFileSystem
	inode_number u32
	inode Inode
}

fn IndexedVNode.new(ifs IndexedFileSystem, inode_number u32, inode Inode) IndexedVNode {
	return IndexedVNode{
		ifs: ifs,
		inode_number: inode_number,
		inode: inode
	}
}

pub fn (vn &IndexedVNode) is_directory() bool {
	return vn.inode.is_directory()
}

pub fn (vn &IndexedVNode) read_at(buf voidptr, len u32, offset u32) ! {
	return error('Not implemented')
}
