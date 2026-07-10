#version 300 es
precision mediump float;

uniform sampler2D prev;
uniform vec2 prev_resolution;
uniform vec2 resolution;
out vec4 out_color;
void main() {
  //vec4 t = texture(prev, gl_FragCoord.xy / resolution);
  //out_color = vec4(t);
  //out_color = vec4(gl_FragCoord.xy / resolution, 0, 1);
  vec2 ts = vec2(textureSize(prev, 0));
  if (ts.x == 1.0 && ts.y == 1.0 && resolution.x > 10.0) {
    vec3 rgb = texture(prev, gl_FragCoord.xy / resolution).rgb;
    out_color = vec4(rgb, 1);
  } else {
    out_color = vec4(0, 0, 0.2, 1.0);
  }
}
