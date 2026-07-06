package main
import "base:runtime"

BumpAllocator :: struct {
	next: uintptr,
	end:  uintptr,
}
bump_allocator :: proc() -> runtime.Allocator {
	data := os_grow_heap(size_of(BumpAllocator))
	ptr := uintptr(raw_data(data))
	bump := (^BumpAllocator)(ptr)
	bump.next = ptr + size_of(BumpAllocator)
	bump.end = ptr + uintptr(len(data))
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
	data: []byte,
	err: runtime.Allocator_Error,
) {
	bump := (^BumpAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			alignment_mask := uintptr(16 - 1)
			next_ptr := (bump.next + alignment_mask) & ~alignment_mask
			next_end := next_ptr + uintptr(size)
			bump.next = next_end
			if next_end > bump.end {
				next_heap_chunk := os_grow_heap(size)
				bump.end = uintptr(&next_heap_chunk[len(next_heap_chunk)])
			}
			data = ([^]u8)(next_ptr)[:size]
			if old_memory != nil {
				copy(data, ([^]u8)(old_memory)[:old_size])
				// TODO: add to free list
			}
		}
	case .Free:
		err = .Mode_Not_Implemented
	case:
		err = .Mode_Not_Implemented
	}
	return
}
