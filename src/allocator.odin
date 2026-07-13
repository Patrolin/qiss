package main
import "base:intrinsics"
import "base:runtime"

MANTISSA_BITS :: 3
MANTISSA_VALUE :: 1 << MANTISSA_BITS

free_index :: proc(block_size: int) -> int {
	if block_size < MANTISSA_VALUE {return block_size}
	exponent := uint(63 - intrinsics.count_leading_zeros(block_size >> MANTISSA_BITS))
	mantissa := uint((block_size >> exponent) & (MANTISSA_VALUE - 1))
	float := int((exponent << MANTISSA_BITS) + mantissa)
	return float
}
alloc_index :: proc(size: int) -> int {
	if size < MANTISSA_VALUE {return size}
	exponent := uint(63 - intrinsics.count_leading_zeros(size >> MANTISSA_BITS))
	mantissa := uint((size >> exponent) & (MANTISSA_VALUE - 1))
	float := int((exponent << MANTISSA_BITS) + mantissa)
	// round up
	low_bits_mask := (1 << (exponent - 1))
	if size & low_bits_mask != 0 {float += 1}
	return float
}

EighthAllocator :: struct {
	next:           uintptr,
	end:            uintptr,
	free_list_mask: [4]u64,
	free_lists:     [256]uintptr,
}
eighth_allocator :: proc() -> runtime.Allocator {
	data := os_grow_heap(size_of(EighthAllocator))
	ptr := uintptr(raw_data(data))
	bump := (^EighthAllocator)(ptr)
	bump.next = ptr + size_of(EighthAllocator)
	bump.end = ptr + uintptr(len(data))
	return runtime.Allocator{eighth_allocator_proc, rawptr(ptr)}
}
eighth_allocator_proc :: proc(
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
	bump := (^EighthAllocator)(allocator_data)
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed, .Resize, .Resize_Non_Zeroed:
		{
			alignment_mask := uintptr(8 - 1)
			next_ptr := (bump.next + alignment_mask) & ~alignment_mask
			next_end := next_ptr + uintptr(size)
			bump.next = next_end
			if next_end > bump.end {
				next_heap_chunk := os_grow_heap(size)
				bump.end = uintptr(&next_heap_chunk[len(next_heap_chunk)])
			}
			data = ([^]u8)(next_ptr)[:size]
			intrinsics.mem_zero(rawptr(next_ptr), size)
			if old_memory != nil {
				copy(data, ([^]u8)(old_memory)[:old_size])
				assert(false, "TODO: add to free list")
			}
		}
	case .Free:
		err = .Mode_Not_Implemented
	case:
		err = .Mode_Not_Implemented
	}
	return
}
