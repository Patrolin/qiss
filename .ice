BUILD :: "odin build opengl -target:freestanding_wasm64p32 -out:dist/opengl.wasm -default-to-nil-allocator -no-entry-point -o:size -print-linker-flags"

build:
  $$BUILD
run:
  $$BUILD
  python -m http.server 3000
