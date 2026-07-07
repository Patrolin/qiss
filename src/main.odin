package main
import "base:runtime"

// globals
default_context: runtime.Context
gl: GlHandle

// exports
@(export)
on_start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	//context.allocator = bump_allocator()
	default_context = context
	gl = wasm_createWebGLContext()
}
@(export)
on_event :: proc "c" (type: WindowEventType, ns, x, y: int) {
	context = default_context
	if (type == .PointerMove) {return}
	printf("odin: %, %, %, %", f_int(type), f_int(ns), f_int(x), f_int(y))
}
@(export)
on_tick :: proc "c" () -> (save_power: bool) {
	context = default_context
	gl_clearColor(gl, 0, 0, 0, 1)
	gl_clear(gl, .COLOR_BUFFER_BIT)
	free_all(context.temp_allocator)
	return true
}
