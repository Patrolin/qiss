// fetch the wasm file
const wasm_file = fetch("/dist/opengl.wasm", {mode: "no-cors"});
/** @type {WebAssembly.Instance} */
let wasm_instance;
/** @type {WebGL2RenderingContext} */
let gl;

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
 * @return {string} */
function string(slice_data, slice_count) {
  /** @type {WebAssembly.Memory} */
  const memory = wasm_instance.exports.memory;
  const slice = new Uint8Array(memory.buffer, Number(slice_data), Number(slice_count));
  //const bytes = new Uint8Array(slice);
  //console.log({slice, bytes})
  return utf8_decoder.decode(slice);
}
/**
 * @param {BigInt} slice_ptr
 * @return {[number, number]} */
function slice(slice_ptr) {
  /** @type {WebAssembly.Memory} */
  const memory = wasm_instance.exports.memory;
  const slice = new BigUint64Array(memory.buffer, Number(slice_ptr), 2);
  const ptr = Number(slice[0]);
  const count = Number(slice[1]);
  return [ptr, count];
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
  wasm_instance.exports.on_event(...args.map(BigInt));
  savePower_resolve();
}
function onResize() {
  const ns = Math.round(performance.now() * 1e6);
  const {clientWidth, clientHeight} = document.body;
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
/** @return {BigInt} */
function glpNewContext() {
  gl = document.querySelector("canvas").getContext("webgl2", {antialias: false});
  if (gl == null) throw new Error("Your browser does not support WebGL!");
  console.log(gl.getParameter(gl.VERSION));
  return BigInt(newHandle(gl));
}
/**
 * @param {BigInt} gl_handle
 * @return {BigInt} */
function glpSetContext(gl_handle) {
  gl = handles.get(Number(gl_handle));
}
/**
 * @param {BigInt} shaders_slice_ptr
 * @return {BigInt} */
function glpCompileProgram(shaders_slice_ptr) {
  const program = gl.createProgram();
  // compile shaders
  /** @type {WebAssembly.Memory} */
  const memory = wasm_instance.exports.memory;
  const [ptr, count] = slice(shaders_slice_ptr)
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
/** @param {BigInt} program_handle */
function glUseProgram(program_handle) {
  const program = handles.get(Number(program_handle));
  gl.useProgram(program);
}
const simpleGlProcs = Object.fromEntries([
  "viewport",
  "clearColor",
  "clear",
].map(key => [`gl${key[0].toUpperCase() + key.slice(1)}`, (...args) => {
  gl[key](...args.map(v => (typeof v === "bigint" ? Number(v) : v)));
}]));

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_printInt: console.log,
    wasm_write,
    glpNewContext,
    glpSetContext,
    glpCompileProgram,
    glUseProgram,
    ...simpleGlProcs,
  },
};
const utf8_decoder = new TextDecoder();
const wasm_promise = WebAssembly.instantiateStreaming(wasm_file, WASM_IMPORTS);
(async () => {
  wasm_instance = (await wasm_promise).instance;
  console.log(wasm_instance);
  wasm_instance.exports.on_start();
  onResize();
  while (true) {
    const savePower = wasm_instance.exports.on_tick();
    await waitForNextFrame(savePower);
  }
})();
