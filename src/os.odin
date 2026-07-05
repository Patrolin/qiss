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
os_sbrk :: proc(delta_bytes: uintptr) -> int {
	when ODIN_ARCH == .wasm64p32 {
		// grow heap in 65536B chunks
		delta_chunks := (delta_bytes + 0xffff) >> 16
		if delta_chunks == 0 {
			return intrinsics.wasm_memory_size(0) << 16
		} else {
			return intrinsics.wasm_memory_grow(0, delta_chunks) << 16
		}
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

// files
os_write :: proc(file: FileHandle, bytes_ptr: [^]byte, bytes_count: int) -> int {
	when ODIN_ARCH == .wasm64p32 {
		return wasm_write(file, bytes_ptr, bytes_count)
	} else {
		assert(false)
	}
	return 0
}
