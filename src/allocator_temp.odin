package main
import "base:intrinsics"
import "base:runtime"

ArenaAllocator :: struct {
	next:  uintptr,
	end:   uintptr,
	start: uintptr,
}
arena_allocator :: proc(size: int) -> runtime.Allocator {
	data := os_grow_heap(size)
	ptr := uintptr(raw_data(data))
	arena := (^ArenaAllocator)(ptr)
	arena.next = ptr + size_of(ArenaAllocator)
	arena.end = ptr + uintptr(len(data))
	arena.start = arena.next
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
	data: []byte,
	err: runtime.Allocator_Error,
) {
	arena := (^ArenaAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			// alloc
			alignment_mask := uintptr(alignment - 1)
			next_ptr := (arena.next + alignment_mask) & ~alignment_mask
			next_end := next_ptr + uintptr(size)
			arena.next = next_end
			if next_end > arena.end {
				err = .Out_Of_Memory
				break
			}
			data = ([^]u8)(next_ptr)[:size]
			intrinsics.mem_zero(rawptr(next_ptr), size)
			// realloc
			if old_memory != nil {
				intrinsics.mem_copy_non_overlapping(raw_data(data), old_memory, old_size)
			}
		}
	case .Free_All:
		arena.next = arena.start
	case .Free:
	/* noop */
	case:
		err = .Mode_Not_Implemented
	}
	return
}
