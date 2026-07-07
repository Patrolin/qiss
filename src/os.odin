package main
import "base:intrinsics"

// syscalls
when ODIN_ARCH == .wasm64p32 {
	foreign import env "env"
	@(default_calling_convention = "c")
	foreign env {
		wasm_printInt :: proc(#any_int value: int) ---
		wasm_write :: proc(file: FileHandle, bytes_ptr: [^]byte, bytes_count: int) -> int ---
		wasm_createWebGLContext :: proc() -> FileHandle ---
		gl_clearColor :: proc(gl: FileHandle, r, g, b, a: f64) ---
		gl_clear :: proc(gl: FileHandle, buffer_type: GL_BUFFER_TYPE) ---
	}
}
GL_BUFFER_TYPE :: enum int {
	COLOR_BUFFER_BIT = 0x4000,
}

// allocations
os_grow_heap :: proc(delta_bytes: int) -> (new_heap_chunk: []byte) {
	assert(delta_bytes > 0)
	when ODIN_ARCH == .wasm64p32 {
		CHUNK_SIZE_BITS :: 16
		CHUNK_SIZE :: (1 << CHUNK_SIZE_BITS)
		delta_chunks := (uintptr(delta_bytes) + (CHUNK_SIZE - 1)) >> CHUNK_SIZE_BITS
		prev_chunks_end := intrinsics.wasm_memory_grow(0, delta_chunks)
		prev_end := ([^]byte)(uintptr(prev_chunks_end) << CHUNK_SIZE_BITS)
		return prev_end[:delta_chunks * CHUNK_SIZE]
	} else {
		assert(false)
	}
	return
}

// files
os_write :: proc(file: FileHandle, bytes_ptr: [^]byte, bytes_count: int) -> (written_bytes: int) {
	when ODIN_ARCH == .wasm64p32 {
		return wasm_write(file, bytes_ptr, bytes_count)
	} else {
		assert(false)
	}
	return
}

// console
FileHandle :: distinct int
STDIN :: FileHandle(0)
STDOUT :: FileHandle(1)
STDERR :: FileHandle(2)

// window
WindowEventType :: enum int {
	Resize,
	PointerMove,
	PointerDown,
	PointerUp,
	PointerCancel,
}
