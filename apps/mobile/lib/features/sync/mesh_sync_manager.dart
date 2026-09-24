import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/sync/mesh_conflict_resolver.dart';
import 'package:archiveme_mobile/features/sync/mesh_key_verifier.dart';
import 'package:archiveme_mobile/features/sync/mesh_sync_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Finds nearby devices. The default scan finds none.
typedef MeshPeerDiscoverer = Future<List<MeshPeer>> Function();

/// Streams mesh peers, transfer rates, the vector queue, and key status.
class MeshSyncManager extends StreamNotifier<MeshSyncState> {
  MeshSyncManager({
    this.meshEnabled,
    this.keyStore,
    this.discoverPeers,
  });

  final bool? meshEnabled;
  final MeshKeyStore? keyStore;
  final MeshPeerDiscoverer? discoverPeers;

  final MemoryMeshKeyStore _ownedStore = MemoryMeshKeyStore();
  late MeshSyncState _latest;

  @override
  Stream<MeshSyncState> build() {
    _latest = MeshSyncState.initial(
      meshEnabled: meshEnabled ?? V1CapabilityRegistry.p2pAndWebRtc,
    );
    unawaited(_refreshKey());
    return Stream<MeshSyncState>.value(_latest);
  }

  Future<void> scan() async {
    final enabled = _latest.meshEnabled;
    final peers = enabled
        ? await (discoverPeers ?? _noPeers)()
        : const <MeshPeer>[];
    var inbound = 0;
    var outbound = 0;
    for (final peer in peers) {
      inbound += peer.bytesPerSecondIn;
      outbound += peer.bytesPerSecondOut;
    }
    _emit(
      _latest.copyWith(
        peers: peers,
        bytesPerSecondIn: inbound,
        bytesPerSecondOut: outbound,
      ),
    );
    await _refreshKey();
    _log(
      enabled
          ? 'Scan finished. ${peers.length} devices.'
          : 'Mesh discovery is off on this device.',
    );
  }

  void setLogging({required bool enabled}) {
    _emit(_latest.copyWith(loggingEnabled: enabled));
    _log(enabled ? 'Mesh log on.' : 'Mesh log off.');
  }

  void setVectorQueue({required int pending, required int completed}) {
    _emit(
      _latest.copyWith(
        pendingVectors: pending < 0 ? 0 : pending,
        completedVectors: completed < 0 ? 0 : completed,
      ),
    );
  }

  Future<void> rotateMasterKey() async {
    final next = MeshKeyVerifier.randomKey();
    await _store.write(next);
    await _refreshKey();
    _log('Master key rotated.');
  }

  /// Applies last-write-wins on the moment time and keeps local graph edits.
  MeshEntryVersion applyRemote({
    required MeshEntryVersion local,
    required MeshEntryVersion remote,
  }) {
    final resolved = MeshConflictResolver.resolve(local: local, remote: remote);
    final keptGraph = _sameEdges(resolved.entityEdgeIds, local.entityEdgeIds);
    _log(
      keptGraph
          ? 'Kept local graph edits for ${resolved.entryId}.'
          : 'Kept the local moment ${resolved.entryId}.',
    );
    return resolved;
  }

  Future<void> _refreshKey() async {
    final key = await _ensureKey();
    final check = await MeshKeyVerifier.verifyLocal(key);
    _emit(
      _latest.copyWith(
        keyValid: check.valid,
        keyFingerprint: check.fingerprint,
      ),
    );
    _log(check.valid ? 'Key check passed.' : 'Key check failed.');
  }

  Future<List<int>> _ensureKey() async {
    final existing = await _store.read();
    if (existing != null && existing.length == MeshKeyVerifier.keyByteLength) {
      return existing;
    }
    final created = MeshKeyVerifier.randomKey();
    await _store.write(created);
    return created;
  }

  MeshKeyStore get _store => keyStore ?? _ownedStore;

  void _emit(MeshSyncState next) {
    _latest = next;
    if (!ref.mounted) return;
    state = AsyncData(next);
  }

  void _log(String line) {
    if (!_latest.loggingEnabled) return;
    final logs = [..._latest.logs, line];
    final trimmed = logs.length > 20 ? logs.sublist(logs.length - 20) : logs;
    _emit(_latest.copyWith(logs: trimmed));
  }

  static Future<List<MeshPeer>> _noPeers() async => const [];

  static bool _sameEdges(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

final meshSyncManagerProvider =
    StreamNotifierProvider<MeshSyncManager, MeshSyncState>(MeshSyncManager.new);
