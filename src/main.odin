package main
import "base:runtime"

// globals
defaultContext: runtime.Context
gl: GlHandle
vertexShader :: #load("s_vertex.glsl", string)
fragmentShader :: #load("s_fragment.glsl", string)

// exports
@(export)
on_start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	//context.allocator = bump_allocator()
	defaultContext = context
	gl = glp_createWebGLContext()
	v_shader := glp_compileShader(gl, .VERTEX_SHADER, raw_data(vertexShader), len(vertexShader))
	f_shader := glp_compileShader(gl, .FRAGMENT_SHADER, raw_data(fragmentShader), len(fragmentShader))
	program := glp_linkProgram(gl, v_shader, f_shader)

}
@(export)
on_event :: proc "c" (type: WindowEventType, ns, x, y: int) {
	context = defaultContext
	if (type == .PointerMove) {return}
	printf("odin: %, %, %, %", f_int(type), f_int(ns), f_int(x), f_int(y))
}
@(export)
on_tick :: proc "c" () -> (save_power: bool) {
	context = defaultContext
	gl_clearColor(gl, 0, 0, 0, 1)
	gl_clear(gl, .COLOR_BUFFER_BIT)
	free_all(context.temp_allocator)
	return true
}
