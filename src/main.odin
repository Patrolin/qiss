package main
import "base:runtime"

// TODO: use `performance.now()` and `new Worker()` and `OffscreenCanvas` for accurate event times
@(export)
start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	context.allocator = bump_allocator()
	gl := wasm_createWebGLContext()
	print("Hello from Odin!")
	gl_clearColor(gl, 0, 0, 0, 1)
	gl_clear(gl, .COLOR_BUFFER_BIT)
}
