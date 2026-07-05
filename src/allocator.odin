package main
import "base:runtime"

BumpAllocator :: struct {
	next: uintptr,
	end:  uintptr,
}
bump_allocator :: proc() -> runtime.Allocator {
	ptr := uintptr(os_sbrk(size_of(BumpAllocator)))
	info := (^BumpAllocator)(ptr)
	info.next = ptr + size_of(BumpAllocator)
	info.end = uintptr(os_sbrk(0))
	return runtime.Allocator{bump_allocator_proc, rawptr(ptr)}
}
bump_allocator_proc :: proc(
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
	info := (^BumpAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			next_ptr := (uintptr(info.next) + 15) & ~uintptr(15)
			info.next = next_ptr
			if next_ptr > info.end {os_sbrk(uintptr(size))}
			data := ([^]u8)(next_ptr)[:size]
			if old_memory != nil {
				copy(data, ([^]u8)(old_memory)[:old_size])
				// TODO: add to free list
			}
			return data, nil
		}
	case .Free:
		return nil, .Mode_Not_Implemented
	case:
		return nil, .Mode_Not_Implemented
	}
}
