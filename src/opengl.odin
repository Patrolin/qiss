package main

// opengl
GlHandle :: distinct u32
GlTexture :: distinct GlHandle
GlFBO :: distinct GlHandle
GlProgram :: distinct GlHandle
GlShader :: distinct GlHandle
GlVAO :: distinct GlHandle
GlVBO :: distinct GlHandle
GlEBO :: distinct GlHandle
GlLocation :: distinct i32

GlShaderType :: enum i32 {
	FRAGMENT_SHADER = 35632,
	VERTEX_SHADER   = 35633,
}
GlShaderParam :: enum i32 {
	SHADER_TYPE    = 35663,
	DELETE_STATUS  = 35712,
	COMPILE_STATUS = 35713,
}
GlProgramParam :: enum i32 {
	DELETE_STATUS = 35712,
	LINK_STATUS   = 35714,
}
GlBufferBits :: bit_set[enum i32 {
	COLOR_BUFFER_BIT = 14,
};i32]
GlBufferType :: enum i32 {
	ARRAY_BUFFER         = 34962,
	ELEMENT_ARRAY_BUFFER = 34963,
}
GlBufferUsage :: enum i32 {
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
GlType :: enum i32 {
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
GlDrawMode :: enum i32 {
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
		// glp
		wasmGetWebGLContext :: proc() ---
		glCreateVertexArray :: proc() -> GlVAO ---
		glCreateArrayBuffer :: proc() -> GlVBO ---
		glCreateElementBuffer :: proc() -> GlEBO ---
		glCreateProgram :: proc() -> GlProgram ---
		glCreateShader :: proc(type: GlShaderType) -> GlShader ---
		glShaderSource :: proc(shader: GlShader, source_data: [^]byte, source_count: int) ---
		glCompileShader :: proc(shader: GlShader) ---
		glGetShaderParameter :: proc(shader: GlShader, param: GlShaderParam) -> i32 ---
		glGetShaderInfoLog :: proc(shader: GlShader, buffer_size: i32, written_size: ^i32, buffer: [^]byte) ---
		glAttachShader :: proc(program: GlProgram, shader: GlShader) ---
		glDeleteShader :: proc(shader: GlShader) ---
		glLinkProgram :: proc(program: GlProgram) ---
		glValidateProgram :: proc(program: GlProgram) ---
		glGetProgramParameter :: proc(program: GlProgram, param: GlProgramParam) -> i32 ---
		glGetProgramInfoLog :: proc(program: GlProgram, buffer_size: i32, written_size: ^i32, buffer: [^]byte) ---
		glViewport :: proc(#any_int x, y, width, height: i32) ---
		// gl userspace
		glClearColor :: proc(r, g, b, a: f64) ---
		glClear :: proc(buffer_types: GlBufferBits) ---
		glBindVertexArray :: proc(vao: GlVAO) ---
		glBindArrayBuffer :: proc(vbo: GlVBO) ---
		glBindElementBuffer :: proc(vbo: GlEBO) ---
		glBufferData :: proc(type: GlBufferType, buffer: rawptr, buffer_size: int, usage: GlBufferUsage) ---
		glVertexAttribPointer :: proc(#any_int location: u32, #any_int count: i32, type: GlType, normalize: bool, #any_int vertex_size: u32, #any_int offset: uintptr) ---
		glEnableVertexAttribArray :: proc(#any_int location: u32) ---
		glUseProgram :: proc(program: GlProgram) ---
		glGetUniformLocation :: proc(program: GlProgram, name: cstring) -> GlLocation ---
		glUniform2f :: proc(location: GlLocation, x, y: f32) ---
		glDrawArrays :: proc(mode: GlDrawMode, #any_int start, count: i32) ---
	}
}

// glp
ShaderDescription :: struct {
	type:   GlShaderType,
	source: string,
}
GlpStep :: struct {
	texture: GlTexture,
	fbo:     GlFBO,
	width:   i32,
	height:  i32,
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
glpCover_vao := GlVAO(0)
glpCover_vertices := GlVBO(0)
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
	glpCover_vao = glCreateVertexArray()
	glBindVertexArray(glpCover_vao)
	// setup glpCoverVbo
	glpCover_vertices = glCreateArrayBuffer()
	glBindArrayBuffer(glpCover_vertices)
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
	// create buffers
	if (shader.flags >= {.Cover}) {
		shader.vao = glpCover_vao
		shader.vertices = glpCover_vertices
	} else {
		shader.vao = glCreateVertexArray()
		shader.vertices = glCreateArrayBuffer()
	}
	if (shader.flags >= {.Elements}) {shader.elements = glCreateElementBuffer()}
	if (shader.flags >= {.Instances}) {shader.instances = glCreateArrayBuffer()}
	shader.program = glCreateProgram()
	// compile shaders
	shaderDescriptions := [?]ShaderDescription{{.VERTEX_SHADER, shader.vertex}, {.FRAGMENT_SHADER, shader.fragment}}
	for shaderDescription in shaderDescriptions {
		if len(shaderDescription.source) == 0 {continue}
		glShader := glCreateShader(shaderDescription.type)
		assert(glShader != 0)
		glShaderSource(glShader, raw_data(shaderDescription.source), len(shaderDescription.source))
		glCompileShader(glShader)
		if (glGetShaderParameter(glShader, .COMPILE_STATUS) == 0) {
			print(shaderDescription.source)
			buffer: [4096]byte = ---
			written_size: i32
			glGetShaderInfoLog(glShader, len(buffer), &written_size, &buffer[0])
			log := transmute(string)(buffer[:written_size])
			print(log)
			assert(false, log)
		}
		glAttachShader(shader.program, glShader)
		glDeleteShader(glShader)
	}
	// link program
	glLinkProgram(shader.program)
	glValidateProgram(shader.program)
	if (glGetProgramParameter(shader.program, .LINK_STATUS) == 0) {
		buffer: [4096]byte = ---
		written_size: i32
		glGetProgramInfoLog(shader.program, len(buffer), &written_size, &buffer[0])
		log := transmute(string)(buffer[:written_size])
		print(log)
		assert(false, log)
	}
}
glpStep :: proc(step: ^GlpStep, #any_int width, height: i32, present := false) {
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
	glpPreviousStep = nil
	glpCurrentStep = nil
}
