// fetch the wasm file
const wasm_file = fetch("/dist/opengl.wasm", {mode: "no-cors"});
/** @type {WebAssembly.Instance} */
let wasm_instance;
/** @type {OffscreenCanvas} */
let wasm_canvas;

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
 *  @param {BigInt} file
 *  @param {BigInt} bytes_ptr
 *  @param {BigInt} bytes_count */
function wasm_write(file, bytes_ptr, bytes_count) {
  const memory = wasm_instance.exports.memory.buffer;
  const bytes = new Uint8Array(memory, Number(bytes_ptr), Number(bytes_count));
  const string = utf8_decoder.decode(bytes);
  if (file == STDOUT) {
    console.log(string);
  } else if (file == STDERR) {
    console.error(string);
  } else {
    throw RangeError(`Cannot write '${string}' to unknown file: ${file}`);
  }
  return bytes_count;
}

// opengl
function wasm_createWebGLContext() {
  const gl = wasm_canvas.getContext("webgl");
  if (gl == null) throw new Error("Your browser does not support WebGL!");
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
const CANVAS_EVENT = -1;
const CLICK_EVENT = 0;
self.onmessage = async ({data}) => {
  //console.log("event", data);
  switch (data.type) {
  case CANVAS_EVENT: {
    wasm_canvas = data.canvas;
  } break;
  case CLICK_EVENT: {
    wasm_instance.exports.on_event(BigInt(data.type), BigInt(data.ns), BigInt(data.x), BigInt(data.y));
  } break;
  default: {
    throw new Error(`Uknown event type: ${data.type}`);
  } break;
  }
}

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_print_int: console.log,
    wasm_write,
    wasm_createWebGLContext,
    ...glProcs,
  },
};
const utf8_decoder = new TextDecoder();
const wasm_promise = WebAssembly.instantiateStreaming(wasm_file, WASM_IMPORTS);
(async () => {
  const instance = (await wasm_promise).instance;
  console.log(wasm_instance);
  instance.exports.on_start();
  wasm_instance = instance;
  while (true) {
    instance.exports.on_tick();
    await new Promise((resolve) => {
      setTimeout(resolve, 17);
      //requestAnimationFrame(resolve);
    });
  }
})();
