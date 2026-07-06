// fetch the wasm file
const wasm_file = fetch("/dist/opengl.wasm", {mode: "no-cors"});
/** @type {WebAssembly.Instance} */
let wasm_instance;

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
 * @param {BigInt} slice_ptr
 * @param {BigInt} slice_count */
function wasm_write(file, slice_ptr, slice_count) {
  /** @type {WebAssembly.Memory} */
  const memory = wasm_instance.exports.memory;
  const slice = new Uint8Array(memory.buffer, Number(slice_ptr), Number(slice_count));
  //const bytes = new Uint8Array(slice);
  //console.log({slice, bytes})
  const string = utf8_decoder.decode(slice);
  if (file == STDOUT) {
    console.log(string);
  } else if (file == STDERR) {
    console.error(string);
  } else {
    throw RangeError(`Cannot write '${string}' to unknown file: ${file}`);
  }
  return slice_count;
}

// opengl
function wasm_createWebGLContext() {
  const gl = document.querySelector("canvas").getContext("webgl2");
  if (gl == null) throw new Error("Your browser does not support WebGL!");
  console.log(gl.getParameter(gl.VERSION));
  return BigInt(newHandle(gl));
}
const glProcs = Object.fromEntries([
  "clearColor",
  "clear"
].map(key => [`gl_${key}`, (glHandle, ...args) => {
  const gl = handles.get(Number(glHandle));
  gl[key](...args.map(v => (typeof v === "bigint" ? Number(v) : v)));
}]));

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
const CLICK_EVENT = 1;
function handleEvent(...args) {
  wasm_instance.exports.on_event(...args.map(BigInt));
  savePower_resolve();
}
window.addEventListener("resize", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const x = document.body.clientWidth;
  const y = document.body.clientHeight;
  handleEvent(RESIZE_EVENT, ns, x, y);
});
window.addEventListener("click", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  const x = event.clientX;
  const y = event.clientY;
  handleEvent(CLICK_EVENT, ns, x, y);
});

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_printInt: console.log,
    wasm_write,
    wasm_createWebGLContext,
    ...glProcs,
  },
};
const utf8_decoder = new TextDecoder();
const wasm_promise = WebAssembly.instantiateStreaming(wasm_file, WASM_IMPORTS);
(async () => {
  const instance = (await wasm_promise).instance;
  console.log(instance);
  instance.exports.on_start();
  wasm_instance = instance;
  while (true) {
    const savePower = instance.exports.on_tick();
    await waitForNextFrame(savePower);
  }
})();
