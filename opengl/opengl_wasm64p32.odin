package main
import "base:runtime"

foreign import env "env"
@(default_calling_convention = "c")
foreign env {
	console_log :: proc(s: string) ---
	console_log_int :: proc(#any_int v: int) ---
	window_requestAnimationFrame :: proc() ---
}

// main
@(export)
start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	context.allocator = dumb_allocator()
	print("Hello from Odin!")
	x := u64(13)
	printf("foo: %", f_u64(&x))
}
