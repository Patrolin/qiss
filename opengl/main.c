// builtins
#define export __attribute__((visibility("default")))

// imports
void console_log_int(int x);

// exports
export void _start() {
  console_log_int(13);
}
