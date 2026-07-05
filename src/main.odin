package main
import "base:runtime"

@(export)
start :: proc "c" () {
	context = runtime.default_context()
	context.temp_allocator = arena_allocator(1024 * 1024)
	context.allocator = bump_allocator()
	print("Hello from Odin!")
	x := u64(13)
	printf("foo: %", f_u64(&x))
}
