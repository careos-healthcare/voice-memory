/// Compile-time gates for local mesh compute offloading.
///
/// Mesh discovery and P2P inference require [V1CapabilityRegistry.localNetwork]
/// and [V1CapabilityRegistry.p2pAndWebRtc] at runtime — see [MeshPermissionGate].
abstract final class MeshComputeFeatureFlags {
  MeshComputeFeatureFlags._();

  /// Master switch for mesh llama.cpp offloading in non-test builds.
  static const bool enableMeshComputeOffload = false;
}
