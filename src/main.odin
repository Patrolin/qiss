package main
import "base:runtime"

@(export)
start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	context.allocator = bump_allocator()
	print("Hello from Odin!")
	gl := wasm_createWebGLContext()
	gl_clearColor(gl, 0, 0, 0, 1)
	gl_clear(gl, .COLOR_BUFFER_BIT)
}
