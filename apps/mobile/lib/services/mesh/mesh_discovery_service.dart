import 'dart:async';

import 'package:archiveme_mobile/services/mesh/mesh_permission_gate.dart';
import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

/// Discovers desktop mesh peers advertising llama.cpp compute on the LAN.
abstract class MeshDiscoveryService {
  Future<List<MeshPeerCapabilities>> discoverDesktopPeers({
    Duration timeout = const Duration(seconds: 2),
  });
}

/// Production discovery stub — returns empty until Bonjour/mDNS native bridge lands.
///
/// Gated by [MeshPermissionGate]; callers should evaluate permission first.
class StubMeshDiscoveryService implements MeshDiscoveryService {
  StubMeshDiscoveryService({MeshPermissionGate? permissionGate})
      : _permissionGate = permissionGate ?? MeshPermissionGate();

  final MeshPermissionGate _permissionGate;

  @override
  Future<List<MeshPeerCapabilities>> discoverDesktopPeers({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final decision = await _permissionGate.evaluate();
    if (!decision.permitted) return const [];

    // Native LAN browse (Bonjour `_archiveme-mesh._tcp`) will plug in here.
    await Future<void>.delayed(timeout);
    return const [];
  }
}

/// In-memory discovery for unit tests and desktop simulators.
class FakeMeshDiscoveryService implements MeshDiscoveryService {
  FakeMeshDiscoveryService({List<MeshPeerCapabilities>? peers, this.delay = Duration.zero})
      : _peers = List<MeshPeerCapabilities>.from(peers ?? const []);

  final List<MeshPeerCapabilities> _peers;
  final Duration delay;
  int discoverCallCount = 0;

  void setPeers(List<MeshPeerCapabilities> peers) {
    _peers
      ..clear()
      ..addAll(peers);
  }

  @override
  Future<List<MeshPeerCapabilities>> discoverDesktopPeers({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    discoverCallCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return List<MeshPeerCapabilities>.unmodifiable(_peers);
  }
}

/// Selects the best capable desktop peer from a discovery result.
MeshPeerCapabilities? selectBestDesktopPeer(List<MeshPeerCapabilities> peers) {
  final capable = peers.where((p) => p.isDesktopLlamaPeer).toList();
  if (capable.isEmpty) return null;

  capable.sort((a, b) {
    final gpuCompare = (b.prefersGpu ? 1 : 0) - (a.prefersGpu ? 1 : 0);
    if (gpuCompare != 0) return gpuCompare;
    final aCtx = a.maxContextTokens ?? 0;
    final bCtx = b.maxContextTokens ?? 0;
    return bCtx.compareTo(aCtx);
  });
  return capable.first;
}
