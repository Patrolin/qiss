package main
import "base:runtime"

// files
vertex_shader :: #load("s_vertex.glsl", string)
fragment_shader :: #load("s_fragment.glsl", string)

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
	glpSetContext(glpNewContext())
	program = glpCompileProgram({.VERTEX_SHADER, vertex_shader}, {.FRAGMENT_SHADER, fragment_shader})
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
	glpStep(window_width, window_height, true)
	glClearColor(0, 0, 0, 1)
	glClear(.COLOR_BUFFER_BIT)

	glUseProgram(program)
	glpDrawCover()
	//vertices := []Vertex{{{0, 0, 0}}, {{1, 0, 0}}, {{1, 1, 0}}, {{0, 1, 0}}}

	glpSwapBuffers()
	free_all(context.temp_allocator)
	return true
}
