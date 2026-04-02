module proc

import file { OpenFileDescriptor }

const max_file_descriptors = 4

const invalid_open_file_descriptor = OpenFileDescriptor(0xff)

pub type LocalFileDescriptor = u8

@[noinit]
pub struct FileDescriptorTable {
pub mut:
	descriptors [max_file_descriptors]OpenFileDescriptor
}

pub fn FileDescriptorTable.new() FileDescriptorTable {
	return FileDescriptorTable{
		descriptors: [max_file_descriptors]OpenFileDescriptor{init: invalid_open_file_descriptor}
	}
}

pub fn (fdt &FileDescriptorTable) at(index LocalFileDescriptor) ?OpenFileDescriptor {
	if index >= fdt.descriptors.len {
		return none
	}
	open_file := fdt.descriptors[index]
	if open_file == invalid_open_file_descriptor {
		return none
	}
	return open_file
}

fn (fdt &FileDescriptorTable) find_available() ?LocalFileDescriptor {
	for i in 0 .. fdt.descriptors.len {
		if fdt.descriptors[i] == invalid_open_file_descriptor {
			return LocalFileDescriptor(i)
		}
	}
	return none
}

pub fn (mut fdt FileDescriptorTable) allocate(gft_fd OpenFileDescriptor) !LocalFileDescriptor {
	descriptor := fdt.find_available() or { return error('No available local file descriptor') }
	fdt.descriptors[descriptor] = gft_fd
	return descriptor
}

pub fn (mut fdt FileDescriptorTable) release(descriptor LocalFileDescriptor) ! {
	_ := fdt.at(descriptor) or { return error('Invalid local file descriptor ${descriptor}') }
	fdt.descriptors[descriptor] = invalid_open_file_descriptor
}
