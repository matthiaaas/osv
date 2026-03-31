module fs

import block { BlockDevice, BlockIo }
import vfs { FileSystem, VNode }
import ds { Bitmap }

const magic = 0x1234_5678
const block_size = 1024 // bytes
const superblock_location = 0
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
const file_type_mask = u16(0o170000)
const file_type_regular = u16(0o100000)
const file_type_directory = u16(0o040000)

struct Inode {
mut:
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
		name_bytes:   name_bytes
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

fn DirectoryBlock.from_bytes(bytes []u8) !DirectoryBlock {
	db := DirectoryBlock{}
	unsafe { vmemcpy(&db, &bytes[0], sizeof(DirectoryBlock)) }
	return db
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

@[heap; noinit]
pub struct IndexedFileSystem implements FileSystem {
	bio        BlockIo
	superblock Superblock
mut:
	inode_bitmap Bitmap
	data_bitmap  Bitmap
}

fn IndexedFileSystem.new(volume BlockDevice, superblock Superblock) !IndexedFileSystem {
	bio := BlockIo.new(volume, block_size)

	mut buf := []u8{len: int(block_size)}
	bio.read(superblock.inode_bitmap_location, mut buf)!
	inode_bitmap := Bitmap.new(buf)
	bio.read(superblock.data_bitmap_location, mut buf)!
	data_bitmap := Bitmap.new(buf)

	return IndexedFileSystem{
		bio:          bio
		superblock:   superblock
		inode_bitmap: inode_bitmap
		data_bitmap:  data_bitmap
	}
}

pub fn IndexedFileSystem.load(device BlockDevice) !IndexedFileSystem {
	mut buf := []u8{len: int(device.sector_size())}
	device.read(superblock_location, mut buf)!
	superblock := Superblock.from_bytes(buf)!
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
	device.write(superblock_location, superblock.to_bytes())!

	bio := BlockIo.new(device, block_size)

	mut inode_bitmap := Bitmap.new([]u8{len: block_size})
	inode_bitmap.set(root_inode_number)
	bio.write(superblock.inode_bitmap_location, inode_bitmap.bytes)!

	mut data_bitmap := Bitmap.new([]u8{len: block_size})
	data_bitmap.set(0)
	bio.write(superblock.data_bitmap_location, data_bitmap.bytes)!

	mut ifs := IndexedFileSystem.new(device, superblock)!

	mut dir_block := DirectoryBlock{}
	dir_block.add(DirectoryEntry.from(root_inode_number, '.'))
	dir_block.add(DirectoryEntry.from(root_inode_number, '..'))
	root_data_block_location := data_region_location + u32(0)
	bio.write_at(root_data_block_location, 0, dir_block.to_bytes())!

	mut root_direct := [direct_block_count]u32{}
	root_direct[0] = root_data_block_location
	root_inode := Inode{
		mode:       file_type_directory
		size:       sizeof(DirectoryEntry) * 2
		link_count: 2
		direct:     root_direct
		indirect:   0
	}
	bio.write_at(inode_table_location + root_inode_number, 0, root_inode.to_bytes())!

	return ifs
}

pub fn (ifs &IndexedFileSystem) root() !VNode {
	root_inode := ifs.read_inode(root_inode_number)!
	return IndexedVNode.new(ifs, root_inode_number, root_inode)
}

fn (ifs &IndexedFileSystem) read_inode(inode_number u32) !Inode {
	mut buf := []u8{len: int(sizeof(Inode))}
	block_idx := inode_table_location + (inode_number * sizeof(Inode)) / block_size
	block_offset := (inode_number * sizeof(Inode)) % block_size
	ifs.bio.read_at(block_idx, block_offset, mut buf)!
	return Inode.from_bytes(buf)!
}

fn (mut ifs IndexedFileSystem) write_inode(inode_number u32, inode &Inode) ! {
	block_idx := ifs.superblock.inode_table_location +
		(inode_number * sizeof(Inode)) / ifs.superblock.block_size
	block_offset := (inode_number * sizeof(Inode)) % ifs.superblock.block_size
	ifs.bio.write_at(block_idx, block_offset, inode.to_bytes())!
}

fn (mut ifs IndexedFileSystem) alloc_inode() !u32 {
	free_inode_idx := ifs.inode_bitmap.find_first_unset() or { return error('No free inodes') }
	ifs.inode_bitmap.set(free_inode_idx)
	ifs.sync_inode_bitmap()!
	return free_inode_idx
}

fn (mut ifs IndexedFileSystem) alloc_data_block() !u32 {
	rel := ifs.data_bitmap.find_first_unset() or { return error('No free data blocks') }
	ifs.data_bitmap.set(rel)
	ifs.sync_data_bitmap()!
	return ifs.superblock.data_region_location + rel
}

fn (ifs &IndexedFileSystem) sync_inode_bitmap() ! {
	ifs.bio.write(ifs.superblock.inode_bitmap_location, ifs.inode_bitmap.bytes)!
}

fn (mut ifs IndexedFileSystem) sync_data_bitmap() ! {
	ifs.bio.write(ifs.superblock.data_bitmap_location, ifs.data_bitmap.bytes)!
}

struct IndexedVNode implements VNode {
mut:
	ifs          &IndexedFileSystem
	inode_number u32
	inode        Inode
}

fn IndexedVNode.new(ifs &IndexedFileSystem, inode_number u32, inode Inode) IndexedVNode {
	return IndexedVNode{
		ifs:          ifs
		inode_number: inode_number
		inode:        inode
	}
}

pub fn (vn &IndexedVNode) is_directory() bool {
	return vn.inode.is_directory()
}

pub fn (vn &IndexedVNode) lookup(name string) !VNode {
	if !vn.is_directory() {
		return error('Not a directory')
	}

	blocks_to_search := (vn.inode.size + block_size - 1) / block_size
	mut buf := []u8{len: int(block_size)}

	for i in 0 .. blocks_to_search {
		phys_block := vn.get_physical_block(i)!

		if phys_block == 0 {
			continue
		}

		vn.ifs.bio.read(phys_block, mut buf)!
		dir_block := DirectoryBlock.from_bytes(buf)!

		if entry := dir_block.find(name) {
			child_inode := vn.ifs.read_inode(entry.inode_number)!
			return IndexedVNode.new(vn.ifs, entry.inode_number, child_inode)
		}
	}

	return error('Entry not found: ${name}')
}

pub fn (vn &IndexedVNode) read_at(buf voidptr, len u32, offset u32) ! {
	if offset >= vn.inode.size {
		// EOF
		return
	}

	read_len := if offset + len > vn.inode.size { vn.inode.size - offset } else { len }

	mut bytes_read := u32(0)
	mut current_offset := offset
	target_ptr := unsafe { byteptr(buf) }

	for bytes_read < read_len {
		logical_block := current_offset / block_size
		block_offset := current_offset % block_size

		chunk_size := u32(int_min(int(block_size - block_offset), int(read_len - bytes_read)))

		phys_block := vn.get_physical_block(logical_block)!
		if phys_block != 0 {
			mut chunk_buf := []u8{len: int(chunk_size)}
			vn.ifs.bio.read_at(phys_block, block_offset, mut chunk_buf)!
			unsafe { vmemcpy(target_ptr + bytes_read, &chunk_buf[0], int(chunk_size)) }
		}

		bytes_read += chunk_size
		current_offset += chunk_size
	}
}

pub fn (mut vn IndexedVNode) write_at(buf voidptr, len u32, offset u32) ! {
	mut bytes_written := u32(0)
	mut current_offset := offset
	src_ptr := unsafe { byteptr(buf) }

	for bytes_written < len {
		logical_block := current_offset / block_size
		block_offset := current_offset % block_size
		chunk_size := u32(int_min(int(block_size - block_offset), int(len - bytes_written)))

		phys_block := vn.get_or_alloc_physical_block(logical_block)!

		mut chunk_buf := []u8{len: int(chunk_size)}
		unsafe { vmemcpy(&chunk_buf[0], src_ptr + bytes_written, int(chunk_size)) }
		vn.ifs.bio.write_at(phys_block, block_offset, chunk_buf)!

		bytes_written += chunk_size
		current_offset += chunk_size
	}

	if current_offset > vn.inode.size {
		vn.inode.size = current_offset
		vn.ifs.write_inode(vn.inode_number, &vn.inode)!
	}
}

pub fn (mut vn IndexedVNode) create(name string, is_directory bool) !VNode {
	if !vn.is_directory() {
		return error('Cannot create "${name}": parent is not a directory')
	}

	if _ := vn.lookup(name) {
		return error('Entry already exists: ${name}')
	}

	new_inode_number := vn.ifs.alloc_inode()!
	mut child_inode := Inode{
		mode:       if is_directory { file_type_directory } else { file_type_regular }
		size:       0
		link_count: 1
		direct:     [direct_block_count]u32{}
		indirect:   0
	}
	vn.ifs.write_inode(new_inode_number, &child_inode)!

	entry := DirectoryEntry.from(new_inode_number, name)
	vn.write_at(&entry, u32(sizeof(DirectoryEntry)), vn.inode.size)!

	if is_directory {
		vn.inode.link_count += 1
		vn.ifs.write_inode(vn.inode_number, &vn.inode)!
	}

	mut child_vnode := IndexedVNode.new(vn.ifs, new_inode_number, child_inode)
	if is_directory {
		dot_entry := DirectoryEntry.from(new_inode_number, '.')
		dot_dot_entry := DirectoryEntry.from(vn.inode_number, '..')
		child_vnode.write_at(&dot_entry, u32(sizeof(DirectoryEntry)), 0)!
		child_vnode.write_at(&dot_dot_entry, u32(sizeof(DirectoryEntry)), u32(sizeof(DirectoryEntry)))!
	}

	return child_vnode
}

pub fn (vn &IndexedVNode) close() ! {}

fn (vn &IndexedVNode) get_physical_block(logical_index u32) !u32 {
	if logical_index < direct_block_count {
		return vn.inode.direct[logical_index]
	}

	indirect_index := logical_index - direct_block_count
	entries_per_block := u32(block_size / sizeof(u32))

	if indirect_index < entries_per_block {
		if vn.inode.indirect == 0 {
			return 0
		}

		mut buf := []u8{len: int(block_size)}
		vn.ifs.bio.read(vn.inode.indirect, mut buf)!

		mut indirect_blocks := []u32{len: int(entries_per_block)}
		unsafe { vmemcpy(&indirect_blocks[0], &buf[0], int(block_size)) }

		return indirect_blocks[indirect_index]
	}

	return error('Block index out of bounds (double-indirect not implemented)')
}

fn (mut vn IndexedVNode) get_or_alloc_physical_block(logical_index u32) !u32 {
	phys_block := vn.get_physical_block(logical_index)!
	if phys_block != 0 {
		return phys_block
	}

	new_block := vn.ifs.alloc_data_block()!

	if logical_index < direct_block_count {
		vn.inode.direct[logical_index] = new_block
	} else {
		indirect_index := logical_index - direct_block_count

		if vn.inode.indirect == 0 {
			vn.inode.indirect = vn.ifs.alloc_data_block()!
			vn.ifs.bio.write(vn.inode.indirect, []u8{len: int(block_size)})!
		}

		mut buf := []u8{len: int(block_size)}
		vn.ifs.bio.read(vn.inode.indirect, mut buf)!

		mut indirect_blocks := []u32{len: int(block_size / sizeof(u32))}
		unsafe { vmemcpy(&indirect_blocks[0], &buf[0], int(block_size)) }

		indirect_blocks[indirect_index] = new_block
		vn.ifs.bio.write(vn.inode.indirect, buf)!
	}

	vn.ifs.write_inode(vn.inode_number, &vn.inode)!
	return new_block
}
