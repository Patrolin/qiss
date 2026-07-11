#version 300 es
precision mediump float;

uniform sampler2D prev;
uniform vec2 resolution;
out vec4 out_color;
void main() {
  vec3 rgb = texture(prev, gl_FragCoord.xy / resolution).rgb;
  out_color = vec4(vec3(1.0) - rgb, 1);
}
