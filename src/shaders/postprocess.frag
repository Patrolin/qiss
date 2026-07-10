#version 300 es
precision mediump float;

uniform vec2 resolution;
out vec4 out_color;
void main() {
  out_color = vec4(gl_FragCoord.xy / resolution, 0.0, 1.0);
}
