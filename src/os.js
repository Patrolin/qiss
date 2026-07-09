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
 * @param {BigInt} slice_data
 * @param {BigInt} slice_count
 * @return {Uint8Array} */
function slice_of_byte(slice_data, slice_count) {
  return new Uint8Array(memory.buffer, Number(slice_data), Number(slice_count));
}
/**
 * @param {BigInt} str_data
 * @param {BigInt} str_count
 * @return {string} */
function string(str_data, str_count) {
  const slice = slice_of_byte(str_data, str_count)
  return utf8_decoder.decode(slice);
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
/** @type {Map<number, any>} */
const handles = new Map();
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
/** @type {{vbo: WebGLBuffer, vao: WebGLVertexArrayObject}} */
let glpDrawCover_data;

/** @return {BigInt} */
function glpNewContext() {
  // new context
  gl = canvas.getContext("webgl2", {antialias: false});
  if (gl == null) throw new Error("Your browser does not support WebGL!");
  console.log(gl.getParameter(gl.VERSION));
  console.log({
    BYTE: gl.BYTE,
    SHORT: gl.SHORT,
    UNSIGNED_BYTE: gl.UNSIGNED_BYTE,
    UNSIGNED_SHORT: gl.UNSIGNED_SHORT,
    FLOAT: gl.FLOAT,
  })
  // setup glpCoverStep
  const vao = gl.createVertexArray();
  const vbo = gl.createBuffer();
  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo);

  const vertices = new Float32Array([-1, -1, 3, -1, -1, 3]);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
  const location = 0;
  const positionCount = 2;
  const vertexSize = positionCount*4;
  gl.vertexAttribPointer(location, positionCount, gl.FLOAT, false, vertexSize, 0);
  gl.enableVertexAttribArray(location);

  glpDrawCover_data = {vao, vbo};
  gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, null);
  return BigInt(newHandle(gl));
}
/**
 * @param {BigInt} gl_handle
 * @return {BigInt} */
function glpSetContext(gl_handle) {
  gl = handles.get(Number(gl_handle));
  console.log("a", {
    HALF_FLOAT: gl.HALF_FLOAT,
    INT: gl.INT,
    UNSIGNED_INT: gl.UNSIGNED_INT,
    INT_2_10_10_10_REV: gl.INT_2_10_10_10_REV,
    UNSIGNED_INT_2_10_10_10_REV: gl.UNSIGNED_INT_2_10_10_10_REV,
  });
}
/**
 * @param {BigInt} shaders_slice_ptr
 * @return {BigInt} */
function glpCompileProgram(shaders_slice_ptr) {
  const program = gl.createProgram();
  // compile shaders
  const [ptr, count] = load_slice(shaders_slice_ptr)
  const data = new BigUint64Array(memory.buffer, ptr, count*3);
  for (let i = 0; i < count; i++) {
    const shaderType = data[i*3];
    const shaderSource = string(data[i*3 + 1], data[i*3 + 2]);
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
  return BigInt(newHandle(program));
}
/** @type {{vao: WebGLVertexArrayObject, vbo: WebGLBuffer, ebo: WebGLBuffer}[]} */
const glpSteps = [];
let glpStepIndex = 0;
const GLP_PRESENT = 0x1;
/**
 * @param {BigInt} width
 * @param {BigInt} height
 * @param {boolean} present */
function glpStep(width, height, present) {
  // TODO: handle `present`
  gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, null);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);

  if (glpStepIndex >= glpSteps.length) {
    const vao = gl.createVertexArray();
    const vbo = gl.createBuffer();
    const ebo = gl.createBuffer();
    glpSteps.push({vao, vbo, ebo});
  }
  const step = glpSteps[glpStepIndex];
	gl.viewport(0, 0, Number(width), Number(height));
  gl.bindVertexArray(step.vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, step.vbo);
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, step.ebo);
  glpStepIndex++;
}
function glpDrawCover() {
  gl.bindVertexArray(glpDrawCover_data.vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, glpDrawCover_data.vbo);
  gl.drawArrays(gl.TRIANGLES, 0, 3);

  gl.bindVertexArray(null);
  gl.bindBuffer(gl.ARRAY_BUFFER, null);
}
function glpSwapBuffers() {
  glpStepIndex = 0;
}
/** @param {BigInt} program_handle */
function glUseProgram(program_handle) {
  const program = handles.get(Number(program_handle));
  gl.useProgram(program);
}
function glBufferData(type, buffer_data, buffer_size, usage) {
  const buffer = slice_of_byte(buffer_data, buffer_size);
  gl.bufferData(Number(type), buffer, Number(usage));
}
const simpleGlProcs = Object.fromEntries([
  "glClearColor",
  "glClear",
  "glDrawArrays",
  "glVertexAttribPointer",
  "glEnableVertexAttribArray",
].map(key => [key, (...args) => {
  gl[key[2].toLowerCase() + key.slice(3)](...args.map(v => (typeof v === "bigint" ? Number(v) : v)));
}]));

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_printInt: console.log,
    wasm_write,
    glpNewContext,
    glpSetContext,
    glpCompileProgram,
    glpStep,
    glpDrawCover,
    glpSwapBuffers,
    glUseProgram,
    glBufferData,
    ...simpleGlProcs,
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
