/** @type {WebAssembly.Instance} */
let wasm_instance;
// fetch and decode wasm file
const WASM_IMPORTS = {
  env: {
    console_log: (slice_ptr) => {
      const memory = wasm_instance.exports.memory.buffer;
      const slice = new BigInt64Array(memory, slice_ptr, 2);
      const bytes = new Uint8Array(memory, Number(slice[0]), Number(slice[1]));
      console.log(utf8_decoder.decode(bytes));
    },
    console_log_int: (int_value) => {
      console.log(int_value);
    },
    window_requestAnimationFrame: window.requestAnimationFrame,
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
