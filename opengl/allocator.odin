package main
import "base:intrinsics"
import "base:runtime"

sbrk :: proc "c" (delta_bytes: uintptr) -> int {
	when ODIN_OS == .Freestanding {
		// Grow heap in 65536B chunks
		delta_chunks := (delta_bytes + 0xffff) >> 16
		if delta_chunks == 0 {
			return intrinsics.wasm_memory_size(0) << 16
		} else {
			return intrinsics.wasm_memory_grow(0, delta_chunks) << 16
		}
	} else {
		assert_contextless(false)
		return 0
	}
}

DumbAllocator :: struct {
	next: uintptr,
	end:  uintptr,
}
dumb_allocator :: proc() -> runtime.Allocator {
	ptr := uintptr(sbrk(size_of(DumbAllocator)))
	info := (^DumbAllocator)(ptr)
	info.next = ptr + size_of(DumbAllocator)
	info.end = uintptr(sbrk(0))
	return runtime.Allocator{dumb_allocator_proc, rawptr(ptr)}
}
dumb_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> (
	[]byte,
	runtime.Allocator_Error,
) {
	info := (^DumbAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			next_ptr := (uintptr(info.next) + 15) & ~uintptr(15)
			info.next = next_ptr
			if next_ptr > info.end {sbrk(uintptr(size))}
			data := ([^]u8)(next_ptr)[:size]
			if old_memory != nil {
				copy(data, ([^]u8)(old_memory)[:old_size])
				// TODO: add to free list
			}
			return data, nil
		}
	case .Free, .Free_All:
		return nil, nil
	case:
		return nil, .Mode_Not_Implemented
	}
}
