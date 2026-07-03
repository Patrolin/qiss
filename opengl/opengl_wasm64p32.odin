package main
import "base:intrinsics"

foreign import env "env"
@(default_calling_convention = "c")
foreign env {
	console_log :: proc(s: string) ---
	console_log_int :: proc(v: int) ---

	virtual_alloc :: proc(size: int) -> uintptr ---
	window_requestAnimationFrame :: proc() ---
}

// main
@(export)
start :: proc "c" () {
	console_log("Hello from Odin!")
	console_log_int(intrinsics.wasm_memory_grow(0, 1))
	console_log("ayaya.2")
	console_log_int(intrinsics.wasm_memory_grow(0, 1))
}
