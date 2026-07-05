const worker = new Worker("/src/os_worker.js");

// window
const CANVAS_EVENT = -1;
const CLICK_EVENT = 0;
document.addEventListener("DOMContentLoaded", () => {
  const canvas = document.querySelector("canvas").transferControlToOffscreen();
  worker.postMessage({ type: CANVAS_EVENT, canvas }, [canvas]);
});
window.addEventListener("click", (event) => {
  const ns = Math.round(performance.now() * 1e6);
  worker.postMessage({
    type: CLICK_EVENT,
    ns,
    x: event.clientX,
    y: event.clientY,
  });
});
