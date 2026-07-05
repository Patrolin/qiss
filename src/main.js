// fetch the wasm file
const wasm_file = fetch("dist/opengl.wasm", {mode: "no-cors"});
/** @type {WebAssembly.Instance} */
let wasm_instance;

// file_handles
/** @type {Map<number, any>} */
const file_handles = new Map();
let next_file_handle = 0;
/**
 * @param {any} value
 * @return {number} */
function newFileHandle(value) {
  const file_handle = next_file_handle;
  file_handles.set(file_handle, value);
  while (file_handles.has(next_file_handle)) {
    next_file_handle = (next_file_handle + 1) | 0;
  }
  return file_handle;
}

// console
const STDIN = newFileHandle();
const STDOUT = newFileHandle();
const STDERR = newFileHandle();
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

// run the wasm
const WASM_IMPORTS = {
  env: {
    wasm_write,
    wasm_requestAnimationFrame: window.requestAnimationFrame,
  },
};
const wasm_promise = WebAssembly.instantiateStreaming(wasm_file, WASM_IMPORTS);
const utf8_decoder = new TextDecoder();
document.addEventListener("DOMContentLoaded", async () => {
  wasm_instance = (await wasm_promise).instance;
  console.log(wasm_instance);
  wasm_instance.exports.start();
});
