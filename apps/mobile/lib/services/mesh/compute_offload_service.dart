import 'dart:async';

import 'package:archiveme_mobile/services/mesh/llama_inference.dart';
import 'package:archiveme_mobile/services/mesh/local_llama_inference.dart';
import 'package:archiveme_mobile/services/mesh/mesh_discovery_service.dart';
import 'package:archiveme_mobile/services/mesh/mesh_peer_transport.dart';
import 'package:archiveme_mobile/services/mesh/mesh_permission_gate.dart';
import 'package:archiveme_mobile/services/mesh/mesh_types.dart';

/// Orchestrates mesh peer discovery, capability handshake, and llama.cpp routing.
///
/// Callers should inject test doubles for [discovery], [transport], and
/// [permissionGate]. On failure the service falls back to [LocalLlamaInference]
/// without throwing.
class ComputeOffloadService {
  ComputeOffloadService({
    MeshDiscoveryService? discovery,
    MeshPeerTransport? transport,
    MeshPermissionGate? permissionGate,
    String? clientId,
    Duration discoveryTimeout = const Duration(seconds: 2),
    Duration handshakeTimeout = const Duration(seconds: 3),
    Duration inferenceTimeout = const Duration(seconds: 30),
  })  : _discovery = discovery ?? StubMeshDiscoveryService(),
        _transport = transport ?? MeshPeerTransport(),
        _permissionGate = permissionGate ?? MeshPermissionGate(),
        _clientId = clientId ?? 'archiveme-mobile',
        _discoveryTimeout = discoveryTimeout,
        _handshakeTimeout = handshakeTimeout,
        _inferenceTimeout = inferenceTimeout;

  final MeshDiscoveryService _discovery;
  final MeshPeerTransport _transport;
  final MeshPermissionGate _permissionGate;
  final String _clientId;
  final Duration _discoveryTimeout;
  final Duration _handshakeTimeout;
  final Duration _inferenceTimeout;

  MeshPeerSession? _cachedSession;
  DateTime? _cachedSessionAt;
  static const _sessionTtl = Duration(minutes: 5);

  /// Runs mesh offload when permitted and a capable peer responds in time.
  Future<LlamaInferenceResponse> infer(
    LlamaInferenceRequest request, {
    LlamaInference? localInference,
  }) async {
    final local = localInference ?? const LocalLlamaInference();

    final permission = await _permissionGate.evaluate();
    if (!permission.permitted) {
      return _fallback(
        local,
        request,
        permission.fallbackReason ?? MeshOffloadFallbackReason.featureDisabled,
      );
    }

    final peers = await _discovery.discoverDesktopPeers(
      timeout: _discoveryTimeout,
    );
    final bestPeer = selectBestDesktopPeer(peers);
    if (bestPeer == null) {
      return _fallback(local, request, MeshOffloadFallbackReason.noCapablePeer);
    }

    final session = await _resolveSession(bestPeer);
    if (session == null) {
      return _fallback(local, request, MeshOffloadFallbackReason.handshakeTimeout);
    }

    final wireResponse = await _transport.infer(
      session: session,
      request: request,
      timeout: _inferenceTimeout,
    );

    if (wireResponse == null) {
      _invalidateSession();
      return _fallback(local, request, MeshOffloadFallbackReason.inferenceTimeout);
    }

    if (wireResponse.error != null && wireResponse.error!.isNotEmpty) {
      _invalidateSession();
      return _fallback(local, request, MeshOffloadFallbackReason.peerRejected);
    }

    return LlamaInferenceResponse(
      text: wireResponse.text,
      route: LlamaInferenceRoute.meshPeer,
      peerId: session.capabilities.peerId,
      tokensUsed: wireResponse.tokensUsed,
    );
  }

  /// Performs capability handshake with a discovered desktop peer.
  Future<MeshPeerSession?> handshakeWithPeer(
    MeshPeerCapabilities peer, {
    Duration? timeout,
  }) {
    return _transport.handshake(
      peer: peer,
      clientId: _clientId,
      timeout: timeout ?? _handshakeTimeout,
    );
  }

  Future<MeshPeerSession?> _resolveSession(MeshPeerCapabilities peer) async {
    final cached = _cachedSession;
    final cachedAt = _cachedSessionAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _sessionTtl &&
        cached.capabilities.peerId == peer.peerId) {
      return cached;
    }

    final session = await handshakeWithPeer(peer);
    if (session == null) return null;

    _cachedSession = session;
    _cachedSessionAt = DateTime.now();
    return session;
  }

  void _invalidateSession() {
    _cachedSession = null;
    _cachedSessionAt = null;
  }

  Future<LlamaInferenceResponse> _fallback(
    LlamaInference local,
    LlamaInferenceRequest request,
    MeshOffloadFallbackReason reason,
  ) async {
    final localResponse = await local.complete(request);
    return LlamaInferenceResponse(
      text: localResponse.text,
      route: LlamaInferenceRoute.onDevice,
      tokensUsed: localResponse.tokensUsed,
      fallbackReason: reason,
    );
  }
}
