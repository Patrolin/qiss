package main

// opengl
GlHandle :: distinct u32
GlTexture :: distinct GlHandle
GlFBO :: distinct GlHandle
GlProgram :: distinct GlHandle
GlVAO :: distinct GlHandle
GlVBO :: distinct GlHandle
GlEBO :: distinct GlHandle
GlLocation :: distinct i32
GlShaderType :: enum int {
	FRAGMENT_SHADER = 35632,
	VERTEX_SHADER   = 35633,
}
GlBufferBits :: bit_set[enum int {
	COLOR_BUFFER_BIT = 14,
};int]
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
GlType :: enum int {
	BYTE = 5120,
	UNSIGNED_BYTE,
	SHORT,
	UNSIGNED_SHORT,
	INT,
	UNSIGNED_INT,
	FLOAT,
	HALF_FLOAT = 5131,
	INT_2_10_10_10_REV = 36255,
	UNSIGNED_INT_2_10_10_10_REV = 33640,
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
	foreign import env "env"
	@(default_calling_convention = "c")
	foreign env {
		wasmGetWebGLContext :: proc() ---
		glCreateVertexArray :: proc() -> GlVAO ---
		glCreateArrayBuffer :: proc() -> GlVBO ---
		glCreateElementBuffer :: proc() -> GlEBO ---
		glViewport :: proc(x, y, width, height: int) ---
		glClearColor :: proc(r, g, b, a: f64) ---
		glClear :: proc(buffer_types: GlBufferBits) ---
		glBindVertexArray :: proc(vao: GlVAO) ---
		glBindArrayBuffer :: proc(vbo: GlVBO) ---
		glBindElementBuffer :: proc(vbo: GlEBO) ---
		glBufferData :: proc(type: GlBufferType, buffer: rawptr, buffer_size: int, usage: GlBufferUsage) ---
		glVertexAttribPointer :: proc(location: int, count: int, type: GlType, normalize: bool, vertex_size: int, #any_int offset: int) ---
		glEnableVertexAttribArray :: proc(location: int) ---
		glUseProgram :: proc(program: GlProgram) ---
		glGetUniformLocation :: proc(program: GlProgram, name: cstring) -> GlLocation ---
		glUniform2f :: proc(location: GlLocation, x, y: f32) ---
		glDrawArrays :: proc(mode: GlDrawMode, start: int, count: int) ---
	}
}

// glp
GlpStep :: struct {
	texture: GlTexture,
	fbo:     GlFBO,
	width:   int,
	height:  int,
}
GlpShaderFlags :: bit_set[enum int {
	Cover,
	Elements,
	Instances,
};int]
GlpShader :: struct {
	program:   GlProgram,
	vao:       GlVAO,
	vertices:  GlVBO,
	elements:  GlEBO,
	instances: GlVBO,
	flags:     GlpShaderFlags,
	vertex:    string,
	fragment:  string,
}
glpCoverVao := GlVAO(0)
glpCoverVbo := GlVBO(0)
glpSteps := [dynamic]GlpStep{}
glpDynamicStepCount := 0
glpPreviousStep := (^GlpStep)(nil)
glpCurrentStep := (^GlpStep)(nil)
glpActiveProgram := GlProgram(0)

glpNewContext :: proc() {
	when ODIN_ARCH == .wasm64p32 {
		wasmGetWebGLContext()
	} else {
		assert(false)
	}
	// setup glpCoverVao
	glpCoverVao = glCreateVertexArray()
	glBindVertexArray(glpCoverVao)
	// setup glpCoverVbo
	glpCoverVbo = glCreateArrayBuffer()
	glBindArrayBuffer(glpCoverVbo)
	vertices := [?]f32{-1, -1, 0, 3, -1, 0, -1, 3, 0}
	glBufferData(.ARRAY_BUFFER, &vertices[0], len(vertices), .STATIC_DRAW)
	// setup glpCover vertex attributes for the vbo (also gets remembered by vao if bound)
	location := 0
	positionCount := 3
	vertexSize := positionCount * size_of(f32)
	glVertexAttribPointer(location, positionCount, .FLOAT, false, vertexSize, 0)
	glEnableVertexAttribArray(location)
	glBindVertexArray(GlVAO(0))
	glBindArrayBuffer(GlVBO(0))
}
glpCompileShader :: proc(shader: ^GlpShader) {
	// TODO: glpCompileShader()
	assert(false)
}
glpStep :: proc(step: ^GlpStep, width, height: int, present := false) {
	// create step if not exists
	step := step
	if (step == nil) {
		glpDynamicStepCount += 1
		if glpDynamicStepCount > len(glpSteps) {
			i := append(&glpSteps, GlpStep{})
			step = &glpSteps[i]
		}
	}
	assert(present) // TODO: handle intermediate steps
	// set width and height
	glViewport(0, 0, width, height)
	step.width = width
	step.height = height
	glpPreviousStep = glpCurrentStep
	glpCurrentStep = step
}
glpUseShader :: proc(shader: ^GlpShader) {
	glBindVertexArray(shader.vao)
	glBindArrayBuffer(shader.vertices)
	glBindElementBuffer(shader.elements)
	glUseProgram(shader.program)
	glpActiveProgram = shader.program
}
glpDrawCover :: proc() {
	step := glpCurrentStep
	resolution_location := glGetUniformLocation(glpActiveProgram, "resolution")
	glUniform2f(resolution_location, f32(step.width), f32(step.height))
	glDrawArrays(.TRIANGLES, 0, 3)
}
glpSwapBuffers :: proc() {
	assert(len(glpSteps) == glpDynamicStepCount) // TODO: truncate `glpSteps` to `glpDynamicStepCount`
	glpDynamicStepCount = 0
}
