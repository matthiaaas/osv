module ds

@[noinit]
pub struct Bitmap {
pub mut:
	bytes []u8
}

pub fn Bitmap.new(bytes []u8) Bitmap {
	return Bitmap{
		bytes: bytes
	}
}

pub fn (bm &Bitmap) is_set(bit u32) bool {
	return bm.bytes[bit / 8] & (1 << (bit % 8)) != 0
}

pub fn (mut bm Bitmap) set(bit u32) {
	bm.bytes[bit / 8] |= 1 << (bit % 8)
}

pub fn (mut bm Bitmap) clear(bit u32) {
	bm.bytes[bit / 8] &= ~(1 << (bit % 8))
}

pub fn (bm &Bitmap) find_first_unset() ?u32 {
	for i in 0 .. bm.bytes.len * 8 {
		if !bm.is_set(i) {
			return i
		}
	}
	return none
}
