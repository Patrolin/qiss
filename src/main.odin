package main
import "base:runtime"

// files
drawShader := GlpShader {
	vertex   = #load("shaders/direct.vert", string),
	fragment = #load("shaders/draw.frag", string),
}
postprocessShader := GlpShader {
	flags    = {.Cover},
	vertex   = #load("shaders/direct.vert", string),
	fragment = #load("shaders/postprocess.frag", string),
}

// globals
defaultContext: runtime.Context
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
	glpInit()
	glpCompileShader(&drawShader)
	glpCompileShader(&postprocessShader)
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
static_step: GlpStep
@(export)
on_tick :: proc "c" () -> (save_power: bool) {
	context = defaultContext
	if false {
		// draw triangle
		glpStep(nil, window_width, window_height)
		glClearColor(0.5, 0, 0, 1)
		glClear({.COLOR_BUFFER_BIT})

		glpUseShader(&drawShader)
		vertices := []Vertex{{{-1, -1, 0}}, {{1, 0, 0}}, {{0, 1, 0}}}
		glBufferData(.ARRAY_BUFFER, raw_data(vertices), len(vertices) * size_of(Vertex), .STREAM_DRAW)
		location := 0
		position_count := len(vertices[0].position)
		glVertexAttribPointer(location, position_count, .FLOAT, false, size_of(Vertex), offset_of(Vertex, position))
		glEnableVertexAttribArray(location)
		glDrawArrays(.TRIANGLES, 0, len(vertices))
		// do postprocessing
		glpStep(nil, window_width, window_height, true)
		glpUseShader(&postprocessShader)
		glpDrawCover()
	} else {
		glpStep(&static_step, window_width, window_height, true)
		glClearColor(0.5, 0, 0, 1)
		glClear({.COLOR_BUFFER_BIT})

		glpUseShader(&drawShader)
		vertices := []Vertex{{{-1, -1, 0}}, {{1, 0, 0}}, {{0, 1, 0}}}
		glBufferData(.ARRAY_BUFFER, raw_data(vertices), len(vertices) * size_of(Vertex), .STREAM_DRAW)
		location := 0
		position_count := len(vertices[0].position)
		glVertexAttribPointer(location, position_count, .FLOAT, false, size_of(Vertex), offset_of(Vertex, position))
		glEnableVertexAttribArray(location)
		glDrawArrays(.TRIANGLES, 0, len(vertices))
	}

	glpSwapBuffers()
	free_all(context.temp_allocator)
	return true
}
