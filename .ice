BUILD_ODIN :: "odin build src -out:dist/opengl.wasm -target:freestanding_wasm64p32 --no-rtti -default-to-nil-allocator -no-entry-point -o:size"
BUILD_C :: "clang -Os -fno-builtin -Wall -Wextra -Wswitch-enum -target wasm64 -nostdlib '-Wl,--allow-undefined,--no-entry,--export=_start' src/main.c -o dist/opengl.wasm"

build-c:
  $$BUILD_C
run-c:
  $$BUILD_C
  python -m http.server 3000
build:
  $$BUILD_ODIN
run:
  $$BUILD_ODIN
  python -m http.server 3000
