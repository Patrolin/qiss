package main
import "base:runtime"

ArenaAllocator :: struct {
	next:  uintptr,
	end:   uintptr,
	start: uintptr,
}
arena_allocator :: proc(size: int) -> runtime.Allocator {
	data := os_grow_heap(size)
	ptr := uintptr(raw_data(data))
	wasm_print_int(ptr)
	info := (^ArenaAllocator)(ptr)
	info.next = ptr + size_of(ArenaAllocator)
	info.end = ptr + uintptr(len(data))
	info.start = ptr
	return runtime.Allocator{arena_allocator_proc, rawptr(ptr)}
}
g_lock := false
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
	assert(g_lock == false)
	g_lock = true
	arena := (^ArenaAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			alignment_mask := uintptr(alignment - 1)
			next_ptr := (arena.next + alignment_mask) & ~alignment_mask
			next_end := next_ptr + uintptr(size)
			arena.next = next_end
			if next_end > arena.end {
				err = .Out_Of_Memory
			} else {
				data = ([^]u8)(next_ptr)[:size]
				if old_memory != nil {
					copy(data, ([^]u8)(old_memory)[:old_size])
				}
			}
		}
	case .Free_All:
		arena.next = arena.start
	case .Free:
	case:
		err = .Mode_Not_Implemented
	}
	g_lock = false
}
