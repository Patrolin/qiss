package main
import "base:intrinsics"
import "base:runtime"

/*
	A good allocator should maximize memory efficiency (per used page) by:
	- merging neighbouring free blocks together
	- allocating into the smallest blocks first
*/

// float(mantissa=1, exponent=5)
EXPONENT_OFFSET :: 0
MANTISSA_BITS :: 1
MANTISSA_VALUE :: 1 << MANTISSA_BITS
OFFSET_VALUE :: 1 << (EXPONENT_OFFSET + MANTISSA_BITS)

@(private = "file")
free_index :: proc(#any_int block_size: u64) -> u64 {
	if block_size < OFFSET_VALUE {return block_size >> EXPONENT_OFFSET}
	exponent := 63 - intrinsics.count_leading_zeros(block_size >> MANTISSA_BITS)
	mantissa := (block_size >> exponent) & (MANTISSA_VALUE - 1)
	float := ((exponent - EXPONENT_OFFSET) << MANTISSA_BITS) + mantissa
	return float
}
@(private = "file")
alloc_index :: proc(#any_int size: u64) -> u64 {
	if size < OFFSET_VALUE {return size >> EXPONENT_OFFSET}
	exponent := 63 - intrinsics.count_leading_zeros(size >> MANTISSA_BITS)
	mantissa := (size >> exponent) & (MANTISSA_VALUE - 1)
	float := ((exponent - EXPONENT_OFFSET) << MANTISSA_BITS) + mantissa
	// round up
	low_bits_mask := (u64(1) << (exponent)) - 1
	if size & low_bits_mask != 0 {float += 1}
	return float
}

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

eight_alloc :: proc(eighth: ^EightAllocator, size: int) -> uintptr {
	printf("F: %, %, %", f_int(free_index(9)), f_int(free_index(12)), f_int(free_index(13)))
	printf("A: %, %, %", f_int(alloc_index(9)), f_int(alloc_index(12)), f_int(alloc_index(13)))
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
eight_free :: proc(eighth: ^EightAllocator, old_memory: rawptr, old_size: int) {
	assert(false, "TODO: free")
}

EightAllocator :: struct {
	next:                 uintptr,
	end:                  uintptr,
	available_free_lists: [1]u64,
	free_lists:           [64]uintptr,
}
eight_allocator :: proc() -> runtime.Allocator {
	data := os_grow_heap(size_of(EightAllocator))
	ptr := uintptr(raw_data(data))
	eighth := (^EightAllocator)(ptr)
	eighth.next = ptr + size_of(EightAllocator)
	eighth.end = ptr + uintptr(len(data))
	return runtime.Allocator{eight_allocator_proc, rawptr(ptr)}
}
eight_allocator_proc :: proc(
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
	eighth := (^EightAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			next_ptr := eight_alloc(eighth, size)
			data = ([^]u8)(next_ptr)[:size]
			//intrinsics.mem_zero(rawptr(next_ptr), size)
			//if old_memory != nil {
			//	intrinsics.mem_copy_non_overlapping(raw_data(data), old_memory, old_size)
			//	assert(false, "TODO: add to free list")
			//}
		}
	case .Free:
		eight_free(eighth, old_memory, old_size)
	case:
		err = .Mode_Not_Implemented
	}
	return
}
