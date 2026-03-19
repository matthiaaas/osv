module builtin

// Includes bare implementations as described in
// "v help build-c" for the "-bare-builtin-dir" option.

pub type va_list = voidptr

const uart_base = usize(0x1000_0000)
const page_size = usize(4096)

__global (
    heap_ptr usize
)

fn mmio_write(reg usize, val u8) {
    unsafe {
        volatile ptr := &u8(reg)
        *ptr = val
    }
}

@[export: "bare_print"]
pub fn bare_print(buf &u8, len u64) {
    unsafe {
        for i in u64(0) .. len {
            mmio_write(uart_base, buf[i])
        }
    }
}

@[export: "bare_eprint"]
pub fn bare_eprint(buf &u8, len u64) {
    bare_print(buf, len)
}

@[export: "bare_panic"]
pub fn bare_panic(msg string) {
    bare_print(c"V panic: ", 9)
    bare_print(msg.str, u64(msg.len))
    __exit(1)
}

struct MallocHeader {
pub mut:
    size usize
    page_count usize
}

fn C.kalloc_pages(page_count usize) voidptr
fn C.kfree_pages(base voidptr, page_count usize)

fn C.__kernel_tmp_heap_start()
fn C.__kernel_tmp_heap_end()

fn malloc_bump(n usize) voidptr {
    unsafe {
        if heap_ptr == 0 {
            heap_ptr = usize(voidptr(C.__kernel_tmp_heap_start))
        }
        heap_end := usize(voidptr(C.__kernel_tmp_heap_end))
        if heap_ptr + n > heap_end {
            panic("__malloc: temporary kernel bump heap allocator exhausted")
        }
        start := heap_ptr
        heap_ptr += n
        return voidptr(start)
    }
}

@[export: "malloc"]
pub fn __malloc(n usize) voidptr {
    total := n + sizeof(MallocHeader)
    page_count := (total + page_size - 1) / page_size
    base := C.kalloc_pages(page_count)

    unsafe {
        if base == 0 {
            bump_base := malloc_bump(total)
            header := &MallocHeader(bump_base)
            header.size = n
            header.page_count = 0
            return voidptr(usize(bump_base) + sizeof(MallocHeader))
        }

        header := &MallocHeader(base)
        header.size = n
        header.page_count = page_count
        return voidptr(usize(base) + sizeof(MallocHeader))
    }
}

@[export: "free"]
pub fn __free(ptr voidptr) {
    if ptr == 0 {
        return
    }

    unsafe {
        header_ptr := usize(ptr) - sizeof(MallocHeader)
        header := &MallocHeader(voidptr(header_ptr))
        if header.page_count > 0 {
            C.kfree_pages(voidptr(header_ptr), header.page_count)
        }
    }
}

@[export: "calloc"]
pub fn __calloc(nmemb usize, size usize) voidptr {
    total_size := nmemb * size
    ptr := __malloc(total_size)
    unsafe { memset(ptr, 0, total_size) }
    return ptr
}

@[export: "realloc"]
pub fn realloc(old_area voidptr, new_size usize) voidptr {
    if old_area == 0 {
        return __malloc(new_size)
    }
    if new_size == 0 {
        __free(old_area)
        return voidptr(0)
    }

    mut copy_size := new_size
    unsafe {
        header_ptr := usize(old_area) - sizeof(MallocHeader)
        old_header := &MallocHeader(voidptr(header_ptr))
        if old_header.size < copy_size {
            copy_size = old_header.size
        }
    }

    new_ptr := __malloc(new_size)
    unsafe { memcpy(new_ptr, old_area, copy_size) }
    __free(old_area)
    return new_ptr
}

@[export: "memcpy"]
pub fn memcpy(dest voidptr, src voidptr, n usize) voidptr {
    unsafe {
        d := &u8(dest)
        s := &u8(src)
        for i in usize(0) .. n {
            d[i] = s[i]
        }
    }
    return dest
}

@[export: "memmove"]
pub fn memmove(dest voidptr, src voidptr, n usize) voidptr {
    unsafe {
        d := &u8(dest)
        s := &u8(src)
        if d < s {
            for i in usize(0) .. n {
                d[i] = s[i]
            }
        } else {
            for i := n; i > 0; i-- {
                d[i-1] = s[i-1]
            }
        }
    }
    return dest
}

@[export: "memcmp"]
pub fn memcmp(a voidptr, b voidptr, n usize) int {
    unsafe {
        s1 := &u8(a)
        s2 := &u8(b)
        for i in usize(0) .. n {
            if s1[i] != s2[i] {
                return int(s1[i]) - int(s2[i])
            }
        }
    }
    return 0
}

@[export: "memset"]
pub fn memset(s voidptr, c int, n usize) voidptr {
    unsafe {
        ptr := &u8(s)
        v := u8(c)
        for i in usize(0) .. n {
            ptr[i] = v
        }
    }
    return s
}

@[export: "strlen"]
pub fn strlen(s voidptr) usize {
    unsafe {
        mut i := usize(0)
        str := &u8(s)
        for str[i] != 0 {
            i++
        }
        return i
    }
}

@[export: "vsprintf"]
pub fn vsprintf(str &char, format &char, ap va_list) int { return 0 }

@[export: "vsnprintf"]
pub fn vsnprintf(str &char, size usize, format &char, ap va_list) int { return 0 }

@[export: "getchar"]
pub fn getchar() int { return 0 }

@[export: "bare_backtrace"]
pub fn bare_backtrace() string { return "Backtrace N/A" }

@[export: "exit"]
pub fn __exit(code int) {
    for {}
}
