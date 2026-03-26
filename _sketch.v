// pseudo-code sketch of a vfs kernel implementation

// kernel

struct Kernel {
	// ...
	disk0 Disk
	vfs VirtualFileSystem
	global_file_table GlobalFileTable
}

root_fs := IndexedFileSystem.load(kernel.disk0) or {
    kernel.uart0.puts('Device not formatted. Formatting now...')
    IndexedFileSystem.format(kernel.disk0) or { panic('Failed to format root filesystem') }
}
kernel.vfs.mount('/', root_fs) or { panic('Failed to mount root filesystem') }

// virtual file system

struct Mount {
    prefix string
    fs FileSystem
}

const max_public_mounts = 4

struct VirtualFileSystem {
    public_mounts [max_public_mounts]Mount
    // internal_mounts [4]Mount // e.g. pipefs
}

fn (vfs VirtualFileSystem) mount(prefix string, fs FileSystem) ! {
    public_mounts.add(Mount.new(prefix, fs))! // `add` hides unnecessary complexity
}

fn (vfs VirtualFileSystem) find_mount(path string) ?Mount {
}

fn (vfs VirtualFileSystem) resolve(path string) !VNode {
	mount := vfs.find_mount(path) or { return error('No mount found for path') }
	path_traversal := PathTraversal.from(path.replace(mount.prefix, ""))
	curr_vnode := mount.fs.root()!

	for segment in path_traversal {
		if !curr_vnode.is_directory() {
			return error('Not a directory')
		}

		curr_vnode = curr_vnode.lookup(segment)!
	}

	return curr_vnode
}

interface FileSystem {
    root() !VNode
}

interface VNode {
	is_directory() bool
	lookup(name string) !VNode
	read_at(offset u32, len u32) ![]byte
	// write_at(offset u32, data []byte) !
	// close() !
}

// global file table

struct OpenFileDescription {
    vnode VNode
    position u32
    flags u32
}

const max_open_files = 8

struct GlobalFileTable {
    open_files [max_open_files]OpenFileDescription
}

fn (gft GlobalFileTable) at(index u32) ?OpenFileDescription {
    return gft.open_files[index]?
}

// block & devices

interface BlockDevice {
    sector_count() u32
    sector_size() u32
    read(sector u32) ![]byte
    write(sector u32, data []byte) !
}

struct Disk implements BlockDevice { ... }

struct BlockIo {
    device BlockDevice
    block_size u32
}

fn (bio BlockIo) read(block u32, len u32) ![]byte {
    sectors_per_block := bio.block_size / bio.device.sector_size()
    start_sector := block * sectors_per_block

    mut block_data := []byte{cap: int(bio.block_size * len)}
    for i in 0 .. sectors_per_block * len {
        block_data << bio.device.read(start_sector + i)!
    }

    return block_data
}

// indexed file system

const magic = 0x1234_5678
const block_size = 1024 // bytes

struct Superblock {
    magic u32
    block_size u32
    block_count u32
    inode_bitmap_location u32
    data_bitmap_location u32
    inode_table_location u32
    inode_table_size u32
    data_region_location u32
    data_region_size u32
}

const direct_block_count = 12

struct Inode {
	mode u16
	size       u32
	link_count u32
	direct     [direct_block_count]u32
	indirect   u32
}

fn Superblock.new(block_size u32, block_count u32, /* ... */) Superblock {
    return Superblock{
        magic: magic,
        block_size: block_size,
        block_count: block_count,
        // ...
    }
}

struct IndexedFileSystem implements FileSystem {
    volume BlockDevice
    bio BlockIo
    superblock Superblock
    inode_bitmap Bitmap
    data_bitmap Bitmap
}

fn IndexedFileSystem.new(dev BlockDevice, superblock Superblock) IndexedFileSystem {
    bio := BlockIo.new(device, block_size)

    inode_bitmap := Bitmap.new(bio.read(superblock.inode_bitmap_location, 1)!)
    data_bitmap := Bitmap.new(bio.read(superblock.data_bitmap_location, 1)!)

    return IndexedFileSystem{
        volume: dev,
        bio: bio,
        superblock: superblock,
        inode_bitmap: inode_bitmap,
        data_bitmap: data_bitmap
    }
}

fn IndexedFileSystem.load(dev BlockDevice) !IndexedFileSystem {
    superblock := Superblock.from_bytes(dev.read(0)!)!
    return IndexedFileSystem.new(
        volume: dev,
        superblock: superblock
    )
}

fn IndexedFileSystem.format(dev BlockDevice) !IndexedFileSystem {
    superblock := Superblock.new(
        block_size: block_size,
        block_count: (fs.volume.sector_count() * fs.volume.sector_size()) / block_size,
        // ...
    )
}

fn (fs IndexedFileSystem) root() !VNode {
	root_inode := fs.read_inode(0)!
    return IndexedVNode.new(fs, 0, root_inode)
}

fn (fs IndexedFileSystem) read_inode(inode_number u32) !Inode {
	offset := fs.superblock.inode_table_location + (inode_number * sizeof(Inode))

}

struct IndexedVNode implements VNode {
	fs    IndexedFileSystem
	inode_number u32
	inode Inode
}

fn IndexedVNode.new(fs IndexedFileSystem, inode_number u32, inode Inode) IndexedVNode {
	return IndexedVNode{
		fs: fs,
		inode_number: inode_number,
		inode: inode
	}
}

fn (vn IndexedVNode) is_directory() bool {
	return true // check inode mode
}

fn (vn IndexedVNode) lookup(name string) !VNode {

}

// utils/bitmap

struct Bitmap {
	bytes []byte
}

fn Bitmap.new(bytes []byte) Bitmap {
	return Bitmap{
		bytes: bytes
	}
}

fn (bm Bitmap) is_set(bit u32) bool {
	return bm.bytes[bit / 8] & (1 << (bit % 8)) != 0
}

fn (bm Bitmap) set(bit u32) {
	bm.bytes[bit / 8] |= 1 << (bit % 8)
}

fn (bm Bitmap) clear(bit u32) {
	bm.bytes[bit / 8] &= ~(1 << (bit % 8))
}

// utils/path

struct PathTraversal {
	segments []string
mut:
	idx u32
}

fn PathTraversal.from(path string) PathTraversal {
	return PathTraversal{
		segments: path.split('/').filter(it != ""),
		idx: 0
	}
}

fn (mut pt PathTraversal) next() ?string {
	if pt.idx >= pt.segments.len {
		return none
	}
	defer {
		pt.idx++
	}
	return pt.segments[pt.idx]
}






// struct Inode {
// 	file_type  FileType
// 	size       u32
// 	link_count u32
// 	direct     [direct_block_count]u32
// 	indirect   u32
// }

// struct DirectoryEntry {
// 	inode_number u32
// 	name_bytes   [volume_name_max_bytes]u8
// }
