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
	value:     u64,
	options:   u64,
	procedure: proc(sb: ^StringBuilder, formatter: ^Formatter),
}
f_str :: proc(value: string) -> Formatter {
	return Formatter{u64(uintptr(raw_data(value))), u64(len(value)), f_str_proc}
}
f_str_proc :: proc(sb: ^StringBuilder, formatter: ^Formatter) {
	str := (runtime.Raw_String){([^]u8)(uintptr(formatter.value)), int(formatter.options)}
	sb_print(sb, transmute(string)str)
}
f_uint :: proc(value: u64) -> Formatter {
	return Formatter{value, {}, f_uint_proc}
}
f_uint_proc :: proc(sb: ^StringBuilder, formatter: ^Formatter) {
	value := formatter.value
	buffer: [20]byte
	i := len(buffer) - 1
	for {
		digit := value % 10
		value = value / 10
		buffer[i] = byte('0' + digit)
		if i < 0 || value == 0 {break}
		i -= 1
	}
	sb_print(sb, string(buffer[i:]))
}
f_int :: proc(#any_int value: i64) -> Formatter {
	return Formatter{u64(value), {}, f_int_proc}
}
f_int_proc :: proc(sb: ^StringBuilder, formatter: ^Formatter) {
	value := i64(formatter.value)
	buffer: [20]byte
	i := len(buffer)
	is_negative := value < 0
	if value <= 0 {
		digit := value % 10
		value = value / 10
		i -= 1
		buffer[i] = byte('0' - digit)
		value = -value
	}
	for i >= 0 && value != 0 {
		digit := value % 10
		value = value / 10
		i -= 1
		buffer[i] = byte('0' + digit)
	}
	if is_negative {
		i -= 1
		buffer[i] = '-'
	}
	sb_print(sb, string(buffer[i:]))
}
