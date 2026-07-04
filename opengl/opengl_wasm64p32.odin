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
	context.allocator = dumb_allocator()
	context.temp_allocator = context.allocator
	console_log("Hello from Odin!")
	console_log_int(uintptr(new([dynamic]int)))
	assert_contextless(false)
	console_log_int(uintptr(new([dynamic]int)))
	//console_log(fmt.tprintf("x: %v", 13))
}

my_new :: proc($T: typeid) -> uintptr {
	return size_of(T)
}
