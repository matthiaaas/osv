module vfs

// TODO: zero-copy optimizations -> slicing
// TODO: peek, normalize, is_last

@[noinit]
struct PathTraversal {
	segments []string
mut:
	idx u32
}

fn PathTraversal.from(path string) PathTraversal {
	return PathTraversal{
		segments: path.split('/').filter(it != '')
		idx:      0
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
