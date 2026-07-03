package main
import "base:runtime"
import "core:fmt"

foreign import env "env"
@(default_calling_convention = "c")
foreign env {
	console_log :: proc(s: string) ---
	console_log_int :: proc(v: int) ---
	window_requestAnimationFrame :: proc() ---
}

// main
@(export)
start :: proc "c" () {
	context = runtime.default_context()
	context.allocator = dumb_allocator()
	context.temp_allocator = context.allocator
	console_log("Hello from Odin!")
	console_log(fmt.tprintf("x: %v", 13))
}
