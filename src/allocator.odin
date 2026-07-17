package main
import "base:intrinsics"
import "base:runtime"

/*
	A good allocator must be O(1) and maximize memory efficiency (per used page) by:
	- merging neighbouring free blocks together
	- allocating into the smallest blocks first
*/

// utils
@(private = "file")
free_index :: proc(#any_int block_size: u64) -> u64 {
	if block_size <= 48 {return (block_size - 8) / 8}
	exponent := 63 - intrinsics.count_leading_zeros(block_size)
	return exponent
}
@(private = "file")
alloc_index :: proc(#any_int size: u64) -> u64 {
	if size <= 48 {return (size - 1) / 8}
	exponent := 63 - intrinsics.count_leading_zeros(size)
	// round up
	low_bits_mask := (u64(1) << (exponent)) - 1
	if size & low_bits_mask != 0 {exponent += 1}
	return exponent
}

// allocator
BLOCK_IS_USED :: 1 << (size_of(uintptr) * 8 - 1)
BlockHeader :: struct {
	offset_right_and_flags: u32,
	offset_left:            u32,
}
#assert(size_of(BlockHeader) <= 8)
FreeBlock :: struct {
	using header: BlockHeader,
	next_offset:  u32,
	prev_offset:  u32,
}
#assert(size_of(FreeBlock) <= 16)

FractionalAllocator :: struct {
	next:                 uintptr,
	end:                  uintptr,
	available_free_lists: [1]u64,
	free_lists:           [64]uintptr,
}
fractional_alloc :: proc(eighth: ^FractionalAllocator, size: int) -> uintptr {
	printf("F: %, %, %", f_int(free_index(63)), f_int(free_index(64)), f_int(free_index(65)))
	printf("A: %, %, %", f_int(alloc_index(63)), f_int(alloc_index(64)), f_int(alloc_index(65)))
	// get desired size
	size_index := alloc_index(size)
	size_mask := u64(0xff) << size_index
	// find next free block
	next_free_block: ^FreeBlock
	j := size_index / 64
	available := eighth.available_free_lists[j] & size_mask
	for {
		k := 64 - intrinsics.count_leading_zeros(available)
		if k != 0 {
			// use existing free_list
			index := j * 64 + k
			assert(false, "TODO: use existing free_list")
			break
		}
		j += 1
		if j >= len(eighth.available_free_lists) {
			// grow heap
			next_heap_chunk := os_grow_heap(size)
			eighth.end = uintptr(raw_data(next_heap_chunk)) + uintptr(len(next_heap_chunk))
			next_free_block = (^FreeBlock)(raw_data(next_heap_chunk))
			next_free_block.offset_right_and_flags = u32(len(next_heap_chunk))
			break
		}
		available := eighth.available_free_lists[j]
	}
	// split block
	next_free_block.offset_right_and_flags |= BLOCK_IS_USED
	assert(false, "TODO: split block")
	return 0
}
fractional_free :: proc(eighth: ^FractionalAllocator, old_memory: rawptr, old_size: int) {
	assert(false, "TODO: free")
}

// odin bindings
fractional_allocator :: proc() -> runtime.Allocator {
	data := os_grow_heap(size_of(FractionalAllocator))
	ptr := uintptr(raw_data(data))
	eighth := (^FractionalAllocator)(ptr)
	eighth.next = ptr + size_of(FractionalAllocator)
	eighth.end = ptr + uintptr(len(data))
	return runtime.Allocator{fractional_allocator_proc, rawptr(ptr)}
}
fractional_allocator_proc :: proc(
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
	fractional := (^FractionalAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			next_ptr := fractional_alloc(fractional, size)
			data = ([^]u8)(next_ptr)[:size]
			//intrinsics.mem_zero(rawptr(next_ptr), size)
			//if old_memory != nil {
			//	intrinsics.mem_copy_non_overlapping(raw_data(data), old_memory, old_size)
			//	assert(false, "TODO: add to free list")
			//}
		}
	case .Free:
		fractional_free(fractional, old_memory, old_size)
	case:
		err = .Mode_Not_Implemented
	}
	return
}
