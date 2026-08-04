#include <metal_stdlib>
using namespace metal;

struct Particle {
  float4 positionRadius;
  float4 velocityValence;
};

kernel void spatial_nexus_integrate(
    device Particle *particles [[buffer(0)]],
    constant uint &count [[buffer(1)]],
    constant float &timeStep [[buffer(2)]],
    uint index [[thread_position_in_grid]]) {
  if (index >= count) return;
  Particle particle = particles[index];
  particle.velocityValence.xyz *= 0.92;
  particle.positionRadius.xyz += particle.velocityValence.xyz * timeStep;
  particles[index] = particle;
}

struct VertexOut {
  float4 position [[position]];
  float pointSize [[point_size]];
  float valence;
  float depth;
};

vertex VertexOut spatial_nexus_vertex(
    uint vertexId [[vertex_id]],
    const device Particle *particles [[buffer(0)]],
    constant float4x4 &viewProjection [[buffer(1)]]) {
  Particle particle = particles[vertexId];
  VertexOut out;
  out.position = viewProjection * float4(particle.positionRadius.xyz, 1.0);
  out.pointSize = max(2.0, particle.positionRadius.w * 120.0 / out.position.w);
  out.valence = particle.velocityValence.w;
  out.depth = out.position.w;
  return out;
}

fragment float4 spatial_nexus_fragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]) {
  float distanceFromCenter = distance(pointCoord, float2(0.5));
  if (distanceFromCenter > 0.5) discard_fragment();
  float3 negative = float3(0.35, 0.45, 1.0);
  float3 positive = float3(1.0, 0.48, 0.32);
  float3 color = mix(negative, positive, clamp(in.valence * 0.5 + 0.5, 0.0, 1.0));
  float focus = clamp(1.0 - max(in.depth - 5.0, 0.0) / 30.0, 0.2, 1.0);
  return float4(color * focus, (1.0 - distanceFromCenter * 2.0) * focus);
}
