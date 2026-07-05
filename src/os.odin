package main
import "base:intrinsics"

when ODIN_ARCH == .wasm64p32 {
	foreign import env "env"
	@(default_calling_convention = "c")
	foreign env {
		wasm_write :: proc(file: FileHandle, bytes_ptr: [^]byte, bytes_count: int) -> int ---
		wasm_requestAnimationFrame :: proc() ---
	}
}

// allocations
os_grow_heap :: proc(delta_bytes: int) -> (new_chunk: []byte) {
	assert(delta_bytes > 0)
	when ODIN_ARCH == .wasm64p32 {
		CHUNK_SIZE_BITS :: 16
		CHUNK_SIZE :: (1 << CHUNK_SIZE_BITS)
		delta_chunks := (delta_bytes + (CHUNK_SIZE - 1)) >> 16
		prev_end := ([^]byte)(uintptr(intrinsics.wasm_memory_grow(0, uintptr(delta_chunks)) << 16))
		return prev_end[:delta_chunks * CHUNK_SIZE]
	} else {
		assert(false)
	}
	return {}
}

// files
os_write :: proc(file: FileHandle, bytes_ptr: [^]byte, bytes_count: int) -> int {
	when ODIN_ARCH == .wasm64p32 {
		return wasm_write(file, bytes_ptr, bytes_count)
	} else {
		assert(false)
	}
	return 0
}

// console
FileHandle :: distinct int
STDIN :: FileHandle(0)
STDOUT :: FileHandle(1)
STDERR :: FileHandle(2)
