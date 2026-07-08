package main
import "base:runtime"

// files
vertexShader :: #load("s_vertex.glsl", string)
fragmentShader :: #load("s_fragment.glsl", string)

// globals
defaultContext: runtime.Context
program: GlProgram
window_width := 0
window_height := 0

Vertex :: struct {
	position: [3]f32,
}

// exports
@(export)
on_start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	//context.allocator = bump_allocator()
	defaultContext = context
	glp_setContext(glp_newContext())
	program = glp_compileProgram({.VERTEX_SHADER, vertexShader}, {.FRAGMENT_SHADER, fragmentShader})
}
@(export)
on_event :: proc "c" (type: WindowEventType, ns, x, y: int) {
	context = defaultContext
	#partial switch type {
	case .Resize:
		window_width = x
		window_height = y
	case .PointerMove:
		return
	}
	printf("odin: %, %, %, %", f_int(type), f_int(ns), f_int(x), f_int(y))
}
@(export)
on_tick :: proc "c" () -> (save_power: bool) {
	context = defaultContext
	// clear buffers
	gl_viewport(0, 0, window_width, window_height)
	gl_clearColor(0, 0, 0, 1)
	gl_clear(.COLOR_BUFFER_BIT)
	// render
	gl_useProgram(program)
	vertices := []Vertex{{{0, 0, 0}}, {{1, 0, 0}}, {{1, 1, 0}}, {{0, 1, 0}}}
	// swap buffers (if applicable)
	glp_swapBuffers()
	free_all(context.temp_allocator)
	return true
}
