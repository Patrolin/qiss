package main
import "base:intrinsics"

foreign import env "env"
@(default_calling_convention = "c")
foreign env {
	console_log :: proc(s: string) ---
	console_log_int :: proc(v: int) ---
	window_requestAnimationFrame :: proc() ---
}
/** Grow heap in 65536B chunks */
sbrk :: proc "c" (delta_bytes: uintptr) -> int {
	delta_chunks := (delta_bytes + 0xffff) >> 16
	if delta_chunks == 0 {
		return intrinsics.wasm_memory_size(0) << 16
	} else {
		return intrinsics.wasm_memory_grow(0, delta_chunks) << 16
	}
}

// main
@(export)
start :: proc "c" () {
	console_log("Hello from Odin!")
	console_log_int(sbrk(4096))
}
