#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uPaintColor;
uniform sampler2D uCamera;
uniform sampler2D uWallMask;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 camera = texture(uCamera, uv);
  float mask = texture(uWallMask, uv).r;

  // Replace hue and saturation while retaining the camera pixel luminance.
  float luminance = dot(camera.rgb, vec3(0.2126, 0.7152, 0.0722));
  float paintLuminance = dot(uPaintColor.rgb, vec3(0.2126, 0.7152, 0.0722));
  vec3 painted = uPaintColor.rgb * (luminance / max(paintLuminance, 0.001));
  fragColor = vec4(mix(camera.rgb, painted, mask * uPaintColor.a), camera.a);
}
