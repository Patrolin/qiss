BUILD_ODIN :: "odin build opengl -out:dist/opengl.wasm -target:freestanding_wasm64p32 --no-rtti -default-to-nil-allocator -no-entry-point -o:size"
BUILD_C :: "clang -Os -fno-builtin -Wall -Wextra -Wswitch-enum -target wasm64 -nostdlib '-Wl,--allow-undefined,--no-entry,--export=_start' opengl/main.c -o dist/opengl.wasm"

build:
  $$BUILD_C
run:
  $$BUILD_C
  python -m http.server 3000
build-odin:
  $$BUILD_ODIN
run-odin:
  $$BUILD_ODIN
  python -m http.server 3000
