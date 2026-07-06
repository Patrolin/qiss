const worker = new Worker("/src/os_worker.js");

// window
const CANVAS_EVENT = -1;
const RESIZE_EVENT = 0
const CLICK_EVENT = 1;
document.addEventListener("DOMContentLoaded", () => {
  const canvas = document.querySelector("canvas").transferControlToOffscreen();
  worker.postMessage({ type: CANVAS_EVENT, canvas }, [canvas]);
});
window.addEventListener("resize", (event) => {
  worker.postMessage({
    type: RESIZE_EVENT,
    ns: Math.round(performance.now() * 1e6),
    x: document.body.clientWidth,
    y: document.body.clientHeight,
  });
});
window.addEventListener("click", (event) => {
  worker.postMessage({
    type: CLICK_EVENT,
    ns: Math.round(performance.now() * 1e6),
    x: event.clientX,
    y: event.clientY,
  });
});
