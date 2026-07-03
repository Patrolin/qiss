package main
import "base:intrinsics"

foreign import env "env"
@(default_calling_convention = "c")
foreign env {
	console_log :: proc(s: string) ---
	console_log_int :: proc(v: int) ---
	window_requestAnimationFrame :: proc() ---
}
sbrk :: proc "c" (delta: int) -> int {
	if delta == 0 {
		return intrinsics.wasm_memory_size(0)
	} else {
		return intrinsics.wasm_memory_grow(0, delta)
	}
}

// main
@(export)
start :: proc "c" () {
	console_log("Hello from Odin!")
	console_log_int(sbrk(1))
	console_log("ayaya.2")
	console_log_int(sbrk(-1))
}
//1245184
