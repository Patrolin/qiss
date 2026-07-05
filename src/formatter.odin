package main

import "base:runtime"
// string builder
StringBuilder :: [dynamic]u8
sb_print :: proc(sb: ^StringBuilder, str: string) {
	append_elem_string(sb, str)
}
sb_string :: proc(sb: StringBuilder) -> string {
	return string(sb[:])
}

// printf
print :: proc(str: string) {
	when ODIN_ARCH == .wasm64p32 {
		os_write(STDOUT, raw_data(str), len(str))
	} else {
		assert(false)
	}
}
printf :: proc(format: string, values: ..Formatter) {
	print(tprintf(format, ..values))
}
tprintf :: proc(format: string, values: ..Formatter) -> string {
	sb := make(StringBuilder, context.temp_allocator)
	j := 0
	for i := 0; i < len(format); i += 1 {
		c := format[i]
		if c == '%' && j < len(values) {
			formatter := &values[j]
			formatter.procedure(&sb, formatter)
			j += 1
		} else {
			append_elem(&sb, c)
		}
	}
	return sb_string(sb)
}

// formatters
Formatter :: struct {
	procedure: proc(sb: ^StringBuilder, formatter: ^Formatter),
	ptr:       rawptr,
	//options:   [2]u32,
}
f_u64 :: proc(ptr: ^u64) -> Formatter {
	return Formatter{f_u64_proc, ptr}
}
f_u64_proc :: proc(sb: ^StringBuilder, formatter: ^Formatter) {
	value := (^u64)(formatter.ptr)^
	buffer: [20]byte
	i := 19
	for {
		digit := value % 10
		value = value / 10
		buffer[i] = byte('0' + digit)
		if i < 0 || value == 0 {break}
		i -= 1
	}
	sb_print(sb, string(buffer[i:]))
}
