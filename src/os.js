// fetch the wasm file
const wasm_file = fetch("/dist/opengl.wasm", {mode: "no-cors"});
/** @type {WebAssembly.Instance} */
let instance;
/** @type {WebAssembly.Memory} */
let memory;
/** @type {HTMLCanvasElement} */
let canvas;

// builtins
/**
 * @param {boolean} condition
 * @param {string|undefined} message */
function assert(condition, message) {
  if (!condition) throw new Error(message);
}
/**
 * @param {BigInt} cstr_data
 * @return {string} */
function cstring(cstr_data) {
  const buffer = new Uint8Array(memory.buffer, Number(cstr_data), 64);
  let count = 0;
  while (count < buffer.length) {
    if (buffer[count] == 0) break;
    count++;
  }
  assert(count < buffer.length, "cstring too big");
  return string(cstr_data, count);
}
/**
 * @param {BigInt} str_data
 * @param {BigInt} str_count
 * @return {string} */
function string(str_data, str_count) {
  const slice = slice_of_bytes(str_data, str_count)
  return utf8_decoder.decode(slice);
}
/**
 * @param {BigInt} slice_data
 * @param {BigInt} slice_count
 * @return {Uint8Array} */
function slice_of_bytes(slice_data, slice_count) {
  return new Uint8Array(memory.buffer, Number(slice_data), Number(slice_count));
}
/**
 * @param {BigInt} slice_data
 * @param {BigInt} slice_count
 * @return {Int32Array} */
function slice_of_i32(slice_data, slice_count) {
  return new Int32Array(memory.buffer, Number(slice_data), Number(slice_count));
}
/**
 * @param {BigInt} slice_ptr
 * @return {[number, number]} */
function load_slice(slice_ptr) {
  const slice = new BigUint64Array(memory.buffer, Number(slice_ptr), 2);
  const data = Number(slice[0]);
  const count = Number(slice[1]);
  return [data, count];
}

// files
const INVALID_HANDLE = -1;
/** @type {Map<number, any>} */
const handles = new Map([[INVALID_HANDLE, null]]);
let next_handle = 0;
/**
 * @param {any} value
 * @return {number} */
function newHandle(value) {
  const file_handle = next_handle;
  handles.set(file_handle, value);
  while (handles.has(next_handle)) {
    next_handle = (next_handle + 1) | 0;
  }
  return file_handle;
}

// console
const STDIN = newHandle();
const STDOUT = newHandle();
const STDERR = newHandle();
/**
 * @param {BigInt} file
 * @param {BigInt} slice_data
 * @param {BigInt} slice_count
 * @return {BigInt} */
function wasm_write(file, slice_data, slice_count) {
  const str = string(slice_data, slice_count)
  if (file == STDOUT) {
    console.log(str);
  } else if (file == STDERR) {
    console.error(str);
  } else {
    throw RangeError(`Cannot write '${str}' to unknown file: ${file}`);
  }
  return slice_count;
}

// window
/** @type {(value: any) => void} */
let savePower_resolve = () => {};
/** Allow browser to process inputs and wait for next frame
 * @param {boolean} savePower
 * @return {Promise<void>} */
async function waitForNextFrame(savePower) {
  if (savePower) {
    await new Promise((resolve) => savePower_resolve = resolve);
    await new Promise((resolve) => requestAnimationFrame(resolve));
  } else {
    await new Promise((resolve) => setTimeout(resolve, 17));
  }
}
const RESIZE_EVENT = 0;
const POINTER_MOVE_EVENT = 1;
const POINTER_DOWN_EVENT = 2;
const POINTER_UP_EVENT = 3;
const POINTER_CANCEL_EVENT = 4;
function sendEvent(...args) {
  instance.exports.on_event(...args.map(BigInt));
  savePower_resolve();
}
function onResize() {
  const {clientWidth, clientHeight} = document.body;
  canvas.width = clientWidth;
  canvas.height = clientHeight;
  const ns = Math.round(performance.now() * 1e6);
  sendEvent(RESIZE_EVENT, ns, clientWidth, clientHeight);
}
window.addEventListener("resize", onResize);
window.addEventListener("pointermove", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  sendEvent(POINTER_MOVE_EVENT, ns, clientX, clientY);
});
window.addEventListener("pointerdown", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  sendEvent(POINTER_DOWN_EVENT, ns, clientX, clientY);
});
window.addEventListener("pointerup", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  sendEvent(POINTER_UP_EVENT, ns, clientX, clientY);
});
window.addEventListener("pointercancel", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  sendEvent(POINTER_CANCEL_EVENT, ns, clientX, clientY);
});

// opengl
/** @type {WebGL2RenderingContext} */
let gl;
/** @type {{vao: number, vbo: number}} */
let glpCover_handles;

function glpNewContext() {
  // new context
  gl = canvas.getContext("webgl2", {antialias: false});
  if (gl == null) throw new Error("Your browser does not support WebGL!");
  console.log(gl.getParameter(gl.VERSION));
  // setup glpCover vao
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  // setup glpCover vbo
  const vbo = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  const vertices = new Float32Array([-1, -1, 0, 3, -1, 0, -1, 3, 0]);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
  // setup glpCover vertex attributes for the vbo (also gets remembered by vao if bound)
  const location = 0;
  const positionCount = 3;
  const vertexSize = positionCount*4;
  gl.vertexAttribPointer(location, positionCount, gl.FLOAT, false, vertexSize, 0);
  gl.enableVertexAttribArray(location);
  glpCover_handles = {
    vao: newHandle(vao),
    vbo: newHandle(vbo),
  };
  gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, null);
}
const GLP_COVER = 0x1;
/**
 * @param {BigInt} shader_ptr */
function glpCompileShader(shader_ptr) {
  const HEADER_SIZE = 5;
  const SHADER_TYPES = [gl.VERTEX_SHADER, gl.FRAGMENT_SHADER];
  const data = new BigUint64Array(memory.buffer, shader_ptr, HEADER_SIZE + SHADER_TYPES.length*2);
  // create program
  const program = gl.createProgram();
  const programHandle = BigInt(newHandle(program));
  data[0] = BigInt(programHandle);
  const flags = Number(data[4]);
  if (flags & GLP_COVER) {
    data[1] = BigInt(glpCover_handles.vao);
    data[2] = BigInt(glpCover_handles.vbo);
    data[3] = BigInt(INVALID_HANDLE);
  } else {
    const vao = gl.createVertexArray();
    const vbo = gl.createBuffer();
    const ebo = gl.createBuffer();
    data[1] = BigInt(newHandle(vao));
    data[2] = BigInt(newHandle(vbo));
    data[3] = BigInt(newHandle(ebo));
  }
  // compile shaders
  for (let i = 0; i < SHADER_TYPES.length; i++) {
    const shaderType = SHADER_TYPES[i];
    const shaderSource = string(data[i*2 + HEADER_SIZE], data[i*2 + HEADER_SIZE + 1])
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
/** @type {{texture: WebGLTexture, fbo: WebGLBuffer, width: number, height: number}[]} */
const glpSteps = [];
let glpStepIndex = -1;
/**
 * @param {BigInt} width
 * @param {BigInt} height
 * @param {boolean} present */
function glpStep(width, height, present) {
  width = Number(width);
  height = Number(height);
  // create a new framebuffer
  if (++glpStepIndex >= glpSteps.length) {
    /** @type {WebGLTexture|null} */
    let texture = null;
    /** @type {WebGLFramebuffer|null} */
    let fbo = null;
    if (!present) {
      // create the framebuffer texture
      texture = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      //gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, width, height, 0, gl.RGBA, gl.FLOAT, null);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.bindTexture(gl.TEXTURE_2D, null);
      // create the framebuffer
      fbo = gl.createFramebuffer();
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
      const fboStatus = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
      if (fboStatus != gl.FRAMEBUFFER_COMPLETE) {
        const fboStatus_to_errorMessage = {
          [gl.FRAMEBUFFER_INCOMPLETE_ATTACHMENT]: "FRAMEBUFFER_INCOMPLETE_ATTACHMENT",
          [gl.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT]: "FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT",
          [gl.FRAMEBUFFER_INCOMPLETE_DIMENSIONS]: "FRAMEBUFFER_INCOMPLETE_DIMENSIONS",
          [gl.FRAMEBUFFER_UNSUPPORTED]: "FRAMEBUFFER_UNSUPPORTED",
          [gl.FRAMEBUFFER_INCOMPLETE_MULTISAMPLE]: "FRAMEBUFFER_INCOMPLETE_MULTISAMPLE",
        }
        throw new Error(`Failed to initialize FBO: ${fboStatus_to_errorMessage[fboStatus]}`);
      }
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    }
    glpSteps.push({texture, fbo, width, height});
  }
  const step = glpSteps[glpStepIndex];
  if (present) {
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  } else {
    if (step.width !== width || step.height !== height) {
      gl.bindTexture(gl.TEXTURE_2D, step.texture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.bindTexture(gl.TEXTURE_2D, null);
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, step.fbo);
  }
  gl.activeTexture(gl.TEXTURE0);
  if (glpStepIndex > 0) {
    gl.bindTexture(gl.TEXTURE_2D, glpSteps[glpStepIndex-1].texture);
  } else {
    gl.bindTexture(gl.TEXTURE_2D, null);
  }
	gl.viewport(0, 0, width, height);
  step.width = width;
  step.height = height;
}
/** @type {number} */
let activeProgram;
/** @param {BigInt} shader_ptr */
function glpUseShader(shader_ptr) {
  gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, null);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);

  const data = new BigUint64Array(memory.buffer, shader_ptr, 4);
  const program = handles.get(Number(data[0]));
  gl.useProgram(program);
  activeProgram = program;
  const vao = handles.get(Number(data[1]));
  const vbo = handles.get(Number(data[2]));
  const ebo = handles.get(Number(data[3]));
  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
}
function glpDrawCover() {
  const step = glpSteps[glpStepIndex];
  const resolution_location = gl.getUniformLocation(activeProgram, "resolution");
  gl.uniform2f(resolution_location, step.width, step.height);
  gl.drawArrays(gl.TRIANGLES, 0, 3);
}
function glpSwapBuffers() {
  glpStepIndex = -1;
}
// opengl
function wasmInitOpenGL() {
  gl = canvas.getContext("webgl2", {antialias: false});
}
const glProcs = Object.fromEntries(Object.entries({
  glCreateVertexArray: () => newHandle(gl.createVertexArray()),
  glCreateArrayBuffer: () => newHandle(gl.createBuffer(gl.ARRAY_BUFFER)),
  glCreateElementBuffer: () => newHandle(gl.createBuffer(gl.ELEMENT_ARRAY_BUFFER)),
  glBindVertexArray: 1,
  glBindArrayBuffer: (arrayBuffer_handle) => {
    const arrayBuffer = handles.get(arrayBuffer_handle);
    gl.bindBuffer(gl.ARRAY_BUFFER, arrayBuffer);
  },
  glBindElementBuffer: (elementBuffer_handle) => {
    const elementBuffer = handles.get(elementBuffer_handle);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, elementBuffer);
  },
  glCreateProgram: () => newHandle(gl.createProgram()),
  glCreateShader: (shaderType) => newHandle(gl.createShader(shaderType)),
  glShaderSource: (shader_handle, source_data, source_count) => {
    const shader = handles.get(shader_handle);
    const shaderSource = string(source_data, source_count);
    gl.shaderSource(shader, shaderSource);
  },
  glCompileShader: 1,
  glGetShaderParameter: 1,
  glGetShaderInfoLog: (shader_handle, buffer_size, written_size_ptr, buffer_ptr) => {
    const shader = handles.get(shader_handle);
    const buffer = slice_of_bytes(buffer_ptr, buffer_size);
    const log = gl.getShaderInfoLog(shader);
    const result = new TextEncoder().encodeInto(log, buffer);
    const written_size = slice_of_i32(written_size_ptr, 1);
    written_size[0] = result.written;
  },
  glAttachShader: 2,
  glDeleteShader: 1,
  glLinkProgram: 1,
  glValidateProgram: 1,
  glGetProgramParameter: 1,
  glGetProgramInfoLog: (program_handle, buffer_size, written_size_ptr, buffer_ptr) => {
    const program = handles.get(program_handle);
    const buffer = slice_of_bytes(buffer_ptr, buffer_size);
    const log = gl.getProgramInfoLog(program);
    const result = new TextEncoder().encodeInto(log, buffer);
    const written_size = slice_of_i32(written_size_ptr, 1);
    written_size[0] = result.written;
  },
  glUseProgram: 1,
  glViewport: 0,
  // gl userspace
  glClearColor: 0,
  glClear: 0,
  glBufferData: (type, buffer_data, buffer_size, usage) => {
    const buffer = slice_of_bytes(buffer_data, buffer_size);
    gl.bufferData(type, buffer, usage);
  },
  glVertexAttribPointer: 0,
  glEnableVertexAttribArray: 0,
  glGetUniformLocation: (program_handle, name_cstr) => {
    const name = cstring(name_cstr)
    const program = handles.get(program_handle, name);
    return newHandle(gl.getUniformLocation(program, name));
  },
  glUniform2f: 1,
  glDrawArrays: 0,
  glDrawArraysInstanced: 0,
}).map(([k, v]) => {
  const webglKey = k[2].toLowerCase() + k.slice(3);
  if (typeof v === "function") return [k, v];
  if (v === 0) return [k, (...args) => gl[webglKey](...args)];
  if (v === 1) return [k, (first_handle, ...args) => {
    const first = handles.get(first_handle);
    return gl[webglKey](first, ...args);
  }];
  if (v === 2) return [k, (first_handle, second_handle, ...args) => {
    const first = handles.get(first_handle);
    const second = handles.get(second_handle);
    return gl[webglKey](first, second, ...args);
  }];
  throw new RangeError();
}));

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_printInt: console.log,
    wasm_write,
    wasmInitOpenGL,
    ...glProcs,
  },
};
const utf8_decoder = new TextDecoder();
const wasm_promise = WebAssembly.instantiateStreaming(wasm_file, WASM_IMPORTS);
document.addEventListener("DOMContentLoaded", async () => {
  canvas = document.querySelector("canvas");
  instance = (await wasm_promise).instance;
  memory = instance.exports.memory;
  console.log(instance);
  instance.exports.on_start();
  onResize();
  while (true) {
    const savePower = instance.exports.on_tick();
    await waitForNextFrame(savePower);
  }
});
