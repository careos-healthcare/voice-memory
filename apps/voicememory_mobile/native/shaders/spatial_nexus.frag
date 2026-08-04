#version 450

layout(location = 0) in float valence;
layout(location = 1) in float depth;
layout(location = 0) out vec4 fragmentColor;

void main() {
  float distanceFromCenter = distance(gl_PointCoord, vec2(0.5));
  if (distanceFromCenter > 0.5) discard;
  vec3 negative = vec3(0.35, 0.45, 1.0);
  vec3 positive = vec3(1.0, 0.48, 0.32);
  vec3 color = mix(negative, positive, clamp(valence * 0.5 + 0.5, 0.0, 1.0));
  float focus = clamp(1.0 - max(depth - 5.0, 0.0) / 30.0, 0.2, 1.0);
  fragmentColor = vec4(color * focus, (1.0 - distanceFromCenter * 2.0) * focus);
}
