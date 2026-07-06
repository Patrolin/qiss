BUILD_ODIN :: "odin build src -out:dist/opengl.wasm -target:freestanding_wasm64p32 --no-rtti -default-to-nil-allocator -no-entry-point -o:size"

build:
  $$BUILD_ODIN
run:
  $$BUILD_ODIN
  python -m http.server 3000
