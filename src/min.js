// builtins
/**
 * @param {boolean} condition
 * @param {string|undefined} message */
function assert(condition, message) {
  if (!condition) throw new Error(message);
}

// opengl
/** @type {HTMLCanvasElement} */
let canvas;
/** @type {WebGL2RenderingContext} */
let gl;
/** @type {{vao: WebGLVertexArrayObject, vbo: WebGLBuffer}} */
let glpCover_handles;
function glpNewContext() {
  // new context
  gl = canvas.getContext("webgl2", {antialias: false});
  if (gl == null) throw new Error("Your browser does not support WebGL!");
  console.log(gl.getParameter(gl.VERSION));
  // setup glpCover vbo
  const vbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  const vertices = new Float32Array([-1, -1, 3, -1, -1, 3]);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
  // setup glpCover vao
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  const location = 0;
  const positionCount = 2;
  const vertexSize = positionCount*4;
  gl.vertexAttribPointer(location, positionCount, gl.FLOAT, false, vertexSize, 0);
  gl.enableVertexAttribArray(location);
  glpCover_handles = {
    vao: vao,
    vbo: vbo,
  };
  gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, null);
}

const GLP_COVER = 0x1;
/**
 * @param {{program: WebGLProgram, vertex: string, fragment: string}} shader */
function glpCompileShader(shader_ptr) {
  const {vertex, fragment, flags} = shader_ptr;
  // create program
  const program = gl.createProgram();
  shader_ptr.program = program;
  if (flags & GLP_COVER) {
    shader_ptr.vao = glpCover_handles.vao;
    shader_ptr.vbo = glpCover_handles.vbo;
    shader_ptr.ebo = null;
  } else {
    shader_ptr.vao = gl.createVertexArray();
    shader_ptr.vbo = gl.createBuffer();
    shader_ptr.ebo = gl.createBuffer();
  }
  // compile shaders
  const shaderStrings = [vertex, fragment];
  const SHADER_TYPES = [gl.VERTEX_SHADER, gl.FRAGMENT_SHADER];
  for (let i = 0; i < SHADER_TYPES.length; i++) {
    const shaderType = SHADER_TYPES[i];
    const shaderSource = shaderStrings[i];
    if (!shaderSource) continue;
    const shader = gl.createShader(Number(shaderType));
    assert(shader != null, "shader != null");
    gl.shaderSource(shader, shaderSource);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      console.log(shaderSource);
      throw new Error(gl.getShaderInfoLog(shader));
    }
    gl.attachShader(program, shader);
    gl.deleteShader(shader);
  }
  // link program
  gl.linkProgram(program);
  gl.validateProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const info = gl.getProgramInfoLog(program);
    throw new Error(info);
  }
}
function glpUseShader(shader_ptr) {
  gl.useProgram(shader_ptr.program);
  gl.bindVertexArray(shader_ptr.vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, shader_ptr.vbo);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, shader_ptr.ebo);
}

async function fetchString(url) {
  return (await fetch(url)).text();
}
document.addEventListener("DOMContentLoaded", async () => {
  // init
  const drawProgram = {
    vertex: await fetchString("src/shaders/direct.vert"),
    fragment: await fetchString("src/shaders/draw.frag"),
  };
  const postprocessProgram = {
    vertex: await fetchString("src/shaders/direct.vert"),
    fragment: await fetchString("src/shaders/postprocess.frag"),
  };
  canvas = document.querySelector("canvas");
  const width = document.body.clientWidth;
  const height = document.body.clientHeight;
  canvas.width = width;
  canvas.height = height;
  glpNewContext();
  glpCompileShader(drawProgram);
  glpCompileShader(postprocessProgram);
  console.log(drawProgram);
  console.log(postprocessProgram);

  // create framebuffer texture
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.bindTexture(gl.TEXTURE_2D, null);

  // create framebuffer
  const fbo = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);

  // draw scene
  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, null);
  gl.viewport(0, 0, width, height);
  (() => {
    gl.clearColor(0.5, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    glpUseShader(drawProgram);
    const vertices = new Float32Array([-1, -1, 0, 1, 0, 0, 0, 1, 0]);
    const vertex_count = 3;
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STREAM_DRAW);

    const location = 0;
    const position_count = 3;
    const sizeof_vertex = position_count*4;
    const offsetof_position = 0;
    gl.vertexAttribPointer(location, position_count, gl.FLOAT, false, sizeof_vertex, offsetof_position);
    gl.enableVertexAttribArray(location);
    gl.drawArrays(gl.TRIANGLES, 0, vertex_count);
  })();
  const data = new Uint8Array(width * height * 4);
  gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data);
  console.log(data);

  // postprocess
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.viewport(0, 0, width, height);
  (() => {
    glpUseShader(postprocessProgram);
    const resolutionLocation = gl.getUniformLocation(postprocessProgram.program, "resolution");
    gl.uniform2f(resolutionLocation, width, height);
    const vertices = new Float32Array([-1, -1, 0, -1, 1, 0, 1, 1, 0]);
    const vertex_count = 3;
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STREAM_DRAW);

    const location = 0;
    const position_count = 3;
    const sizeof_vertex = position_count*4;
    const offsetof_position = 0;
    gl.vertexAttribPointer(location, position_count, gl.FLOAT, false, sizeof_vertex, offsetof_position);
    gl.enableVertexAttribArray(location);
    gl.drawArrays(gl.TRIANGLES, 0, vertex_count);
  })();
});
