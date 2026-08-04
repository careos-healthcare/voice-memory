#version 450

layout(location = 0) in vec4 positionRadius;
layout(location = 1) in vec4 velocityValence;
layout(location = 0) out float valence;
layout(location = 1) out float depth;

layout(set = 0, binding = 0) uniform Camera {
  mat4 viewProjection;
} camera;

void main() {
  gl_Position = camera.viewProjection * vec4(positionRadius.xyz, 1.0);
  gl_PointSize = max(2.0, positionRadius.w * 120.0 / gl_Position.w);
  valence = velocityValence.w;
  depth = gl_Position.w;
}
