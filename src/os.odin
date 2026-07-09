package main
import "base:intrinsics"

// syscalls
when ODIN_ARCH == .wasm64p32 {
	foreign import env "env"
	@(default_calling_convention = "c")
	foreign env {
		wasm_printInt :: proc(#any_int value: int) ---
		wasm_write :: proc(file: FileHandle, bytes_ptr: [^]byte, bytes_count: int) -> int ---
	}
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

// opengl
GlHandle :: distinct FileHandle
GlProgram :: distinct GlHandle
GlShaderType :: enum int {
	FRAGMENT_SHADER = 35632,
	VERTEX_SHADER   = 35633,
}
GlShader :: struct {
	type: GlShaderType,
	str:  string,
}
GlBufferBit :: enum int {
	COLOR_BUFFER_BIT = 0x4000,
}
GlBufferType :: enum int {
	ARRAY_BUFFER         = 34962,
	ELEMENT_ARRAY_BUFFER = 34963,
}
GlBufferUsage :: enum int {
	STREAM_DRAW = 35040,
	STREAM_READ,
	STREAM_COPY,
	STATIC_DRAW = 35044,
	STATIC_READ,
	STATIC_COPY,
	DYNAMIC_DRAW = 35048,
	DYNAMIC_READ,
	DYNAMIC_COPY,
}
GlDrawMode :: enum int {
	POINTS,
	LINES,
	LINE_LOOP,
	LINE_STRIP,
	TRIANGLES,
	TRIANGLE_STRIP,
	TRIANGLE_FAN,
}
when ODIN_ARCH == .wasm64p32 {
	@(default_calling_convention = "c")
	foreign env {
		glpNewContext :: proc() -> GlHandle ---
		glpSetContext :: proc(gl: GlHandle) ---
		glpCompileProgram :: proc(shaders: ..GlShader) -> GlProgram ---
		glpStep :: proc(width, height: int, present := false) ---
		glpDrawCover :: proc() ---
		glpSwapBuffers :: proc() ---
		glViewport :: proc(x, y, width, height: int) ---
		glClearColor :: proc(r, g, b, a: f64) ---
		glClear :: proc(buffer_bit: GlBufferBit) ---
		glUseProgram :: proc(program: GlProgram) ---
		glBufferData :: proc(type: GlBufferType, buffer: rawptr, buffer_size: int, usage: GlBufferUsage) ---
		glDrawArrays :: proc(mode: GlDrawMode, start: int, count: int) ---
	}
}
//GlpStep :: struct {texture: ...}
