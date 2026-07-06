package main
import "base:runtime"

g_default_context: runtime.Context
g_gl: FileHandle

@(export)
on_start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	context.allocator = bump_allocator()
	g_default_context = context
	g_gl = wasm_createWebGLContext()
}
@(export)
on_event :: proc "c" (type, ns, x, y: int) {
	context = g_default_context
	type := type
	ns := ns
	x := x
	y := y
	printf("odin: %, %, %, %", f_int(&type), f_int(&ns), f_int(&x), f_int(&y))
}
@(export)
on_tick :: proc "c" () {
	context = g_default_context
	gl_clearColor(g_gl, 0, 0, 0, 1)
	gl_clear(g_gl, .COLOR_BUFFER_BIT)
	free_all(context.temp_allocator)
}
