// fetch the wasm file
const wasm_file = fetch("/dist/opengl.wasm", {mode: "no-cors"});
/** @type {WebAssembly.Instance} */
let wasm_instance;

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
 * @return {BigInt[]} */
function sliceOfInt(slice_ptr) {
  /** @type {WebAssembly.Memory} */
  const memory = wasm_instance.exports.memory;
  const slice = new BigUint64Array(memory.buffer, Number(slice_ptr), 2);
  const slice_data = Number(slice[0]);
  const slice_count = Number(slice[1]);

  const data_bigints = new BigUint64Array(memory.buffer, Number(slice_data), slice_count);
  //const data = new Array(data_bigints.length);
  //for (let i = 0; i < data_bigints.length; i++) {
  //  data[i] = Number(data_bigints[i]);
  //}
  return data_bigints;
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
function handleEvent(...args) {
  wasm_instance.exports.on_event(...args.map(BigInt));
  savePower_resolve();
}
function onResize() {
  const ns = Math.round(performance.now() * 1e6);
  const {clientWidth, clientHeight} = document.body;
  handleEvent(RESIZE_EVENT, ns, clientWidth, clientHeight);
}
window.addEventListener("resize", onResize);
window.addEventListener("pointermove", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  handleEvent(POINTER_MOVE_EVENT, ns, clientX, clientY);
});
window.addEventListener("pointerdown", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  handleEvent(POINTER_DOWN_EVENT, ns, clientX, clientY);
});
window.addEventListener("pointerup", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  handleEvent(POINTER_UP_EVENT, ns, clientX, clientY);
});
window.addEventListener("pointercancel", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const {clientX, clientY} = event;
  handleEvent(POINTER_CANCEL_EVENT, ns, clientX, clientY);
});

// opengl
/** @return {BigInt} */
function glp_createWebGLContext() {
  const gl = document.querySelector("canvas").getContext("webgl2", {antialias: false});
  if (gl == null) throw new Error("Your browser does not support WebGL!");
  console.log(gl.getParameter(gl.VERSION));
  return BigInt(newHandle(gl));
}
/**
 * @param {number} gl_handle
 * @param {number} shader_type
 * @param {number} slice_data
 * @param {number} slice_count
 * @return {BigInt} */
function glp_compileShader(gl_handle, shader_type, slice_data, slice_count) {
  /** @type {WebGL2RenderingContext} */
  const gl = handles.get(Number(gl_handle));
  const shader = gl.createShader(Number(shader_type));
  assert(shader != null, "shader != null");
  const shaderSource = string(slice_data, slice_count);
  gl.shaderSource(shader, shaderSource);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.log(shaderSource);
    throw new Error(gl.getShaderInfoLog(shader));
  }
  return BigInt(newHandle(shader));
}
function glp_linkProgram(glHandle, shaders_handles_ptr) {
  /** @type {WebGL2RenderingContext} */
  const gl = handles.get(Number(glHandle));
  const program = gl.createProgram();
  for (const shader_handle of sliceOfInt(shaders_handles_ptr)) {
    const shader = handles.get(Number(shader_handle));
    gl.attachShader(program, shader);
    gl.deleteShader(shader);
  }
  gl.linkProgram(program);
  gl.validateProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const info = gl.getProgramInfoLog(program);
    throw new Error(info);
  }
  return BigInt(newHandle(program));
}
function gl_useProgram(gl_handle, program_handle) {
  const gl = handles.get(Number(gl_handle));
  const program = handles.get(Number(program_handle));
  gl.useProgram(program);
}
const simpleGlProcs = Object.fromEntries([
  "viewport",
  "clearColor",
  "clear",
].map(key => [`gl_${key}`, (gl_handle, ...args) => {
  const gl = handles.get(Number(gl_handle));
  gl[key](...args.map(v => (typeof v === "bigint" ? Number(v) : v)));
}]));

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_printInt: console.log,
    wasm_write,
    glp_createWebGLContext,
    glp_compileShader,
    glp_linkProgram,
    gl_useProgram,
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
