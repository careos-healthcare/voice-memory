import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/services/mesh/mesh_compute_feature_flags.dart';
import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

/// Why mesh compute offloading was blocked before discovery/handshake.
enum MeshPermissionBlockReason {
  featureDisabled,
  capabilityDisabled,
  localNetworkPermissionDenied,
}

/// Result of evaluating whether mesh compute may run.
class MeshPermissionDecision {
  const MeshPermissionDecision({
    required this.permitted,
    this.reason,
  });

  const MeshPermissionDecision.permitted() : permitted = true, reason = null;

  const MeshPermissionDecision.denied({required this.reason}) : permitted = false;

  final bool permitted;
  final MeshPermissionBlockReason? reason;

  MeshOffloadFallbackReason? get fallbackReason => switch (reason) {
    MeshPermissionBlockReason.featureDisabled =>
      MeshOffloadFallbackReason.featureDisabled,
    MeshPermissionBlockReason.capabilityDisabled =>
      MeshOffloadFallbackReason.capabilityDisabled,
    MeshPermissionBlockReason.localNetworkPermissionDenied =>
      MeshOffloadFallbackReason.localNetworkPermissionDenied,
    null => null,
  };
}

/// Injectable local-network permission probe — mirrors MCP permission gateways.
abstract class LocalNetworkPermissionGateway {
  Future<bool> isGranted();
  Future<bool> request();
}

/// Default gateway: capability registry only (no OS prompt in V1).
class RegistryLocalNetworkPermissionGateway
    implements LocalNetworkPermissionGateway {
  RegistryLocalNetworkPermissionGateway({
    bool? meshFeatureEnabled,
    bool? localNetworkEnabled,
    bool? p2pEnabled,
  })  : _meshFeatureEnabled =
            meshFeatureEnabled ?? MeshComputeFeatureFlags.enableMeshComputeOffload,
        _localNetworkEnabled =
            localNetworkEnabled ?? V1CapabilityRegistry.localNetwork,
        _p2pEnabled = p2pEnabled ?? V1CapabilityRegistry.p2pAndWebRtc;

  final bool _meshFeatureEnabled;
  final bool _localNetworkEnabled;
  final bool _p2pEnabled;

  @override
  Future<bool> isGranted() async {
    if (!_meshFeatureEnabled) return false;
    if (!_localNetworkEnabled || !_p2pEnabled) return false;
    return true;
  }

  @override
  Future<bool> request() async => isGranted();
}

/// Central gate for mesh compute — feature flag, capability registry, OS permission.
class MeshPermissionGate {
  MeshPermissionGate({
    LocalNetworkPermissionGateway? localNetworkPermission,
    bool? meshFeatureEnabled,
  })  : _localNetworkPermission =
            localNetworkPermission ??
            RegistryLocalNetworkPermissionGateway(
              meshFeatureEnabled: meshFeatureEnabled,
            ),
        _meshFeatureEnabled =
            meshFeatureEnabled ?? MeshComputeFeatureFlags.enableMeshComputeOffload;

  final LocalNetworkPermissionGateway _localNetworkPermission;
  final bool _meshFeatureEnabled;

  Future<MeshPermissionDecision> evaluate() async {
    if (!_meshFeatureEnabled) {
      return const MeshPermissionDecision.denied(
        reason: MeshPermissionBlockReason.featureDisabled,
      );
    }

    final granted = await _localNetworkPermission.isGranted();
    if (!granted) {
      return const MeshPermissionDecision.denied(
        reason: MeshPermissionBlockReason.localNetworkPermissionDenied,
      );
    }

    return const MeshPermissionDecision.permitted();
  }
}

/// Test double for local network permission.
class FakeLocalNetworkPermissionGateway implements LocalNetworkPermissionGateway {
  FakeLocalNetworkPermissionGateway({this.granted = false});

  bool granted;
  int requestCallCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCallCount++;
    return granted;
  }
}
