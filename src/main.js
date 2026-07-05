// platform
/** @type {WebAssembly.Instance} */
let wasm_instance;
/**
 *  @param {BigInt} file
 *  @param {BigInt} bytes_ptr
 *  @param {BigInt} bytes_count */
function wasm_write(file, bytes_ptr, bytes_count) {
  const memory = wasm_instance.exports.memory.buffer;
  const bytes = new Uint8Array(memory, Number(bytes_ptr), Number(bytes_count));
  const string = utf8_decoder.decode(bytes);
  if (file == 1) {
    console.log(string);
  } else if (file == 2) {
    console.error(string);
  } else {
    throw RangeError(`Cannot write '${string}' to unknown file: ${file}`);
  }
  return bytes_count;
}
// fetch and decode the wasm
const WASM_IMPORTS = {
  env: {
    wasm_write,
    wasm_requestAnimationFrame: window.requestAnimationFrame,
  },
};
const wasm_promise = WebAssembly.instantiateStreaming(fetch("dist/opengl.wasm"), WASM_IMPORTS);
// run the wasm
const utf8_decoder = new TextDecoder();
document.addEventListener("DOMContentLoaded", async () => {
  wasm_instance = (await wasm_promise).instance;
  console.log(wasm_instance);
  wasm_instance.exports.start();
});
