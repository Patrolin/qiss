package main
import "base:runtime"

ArenaAllocator :: struct {
	next:  uintptr,
	end:   uintptr,
	start: uintptr,
}
arena_allocator :: proc(size: uint) -> runtime.Allocator {
	data := os_grow_heap(size_of(ArenaAllocator))
	ptr := uintptr(raw_data(data))
	info := (^ArenaAllocator)(ptr)
	info.next = ptr + size_of(ArenaAllocator)
	info.end = ptr + uintptr(len(data))
	info.start = ptr
	return runtime.Allocator{arena_allocator_proc, rawptr(ptr)}
}
arena_allocator_proc :: proc(
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
	info := (^ArenaAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			alignment_mask := uintptr(alignment - 1)
			next_ptr := (info.next + alignment_mask) & ~alignment_mask
			info.next = next_ptr
			if next_ptr > info.end {return nil, .Out_Of_Memory}
			data := ([^]u8)(next_ptr)[:size]
			if old_memory != nil {
				copy(data, ([^]u8)(old_memory)[:old_size])
			}
			return data, nil
		}
	case .Free_All:
		info.next = info.start
		return nil, nil
	case .Free:
		return nil, nil
	case:
		return nil, .Mode_Not_Implemented
	}
}
