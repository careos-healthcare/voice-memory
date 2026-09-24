import 'package:archiveme_mobile/desktop/vault_sync_status.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/services/mesh/mesh_permission_gate.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';

/// One encrypted sync record held on device until a peer channel exists.
class MeshOffloadRecord {
  const MeshOffloadRecord({required this.id, required this.envelope});

  final String id;
  final EncryptedPayload envelope;
}

/// Result of sealing a payload into the local queue.
class MeshOffloadEnqueueResult {
  const MeshOffloadEnqueueResult({
    required this.queued,
    required this.peers,
    required this.sent,
  });

  final bool queued;
  final PeerSyncStatus peers;
  final bool sent;
}

/// Result of attempting to hand the local queue to peers.
class MeshOffloadFlushResult {
  const MeshOffloadFlushResult({
    required this.peers,
    required this.delivered,
    required this.retained,
  });

  final PeerSyncStatus peers;
  final int delivered;
  final int retained;
}

/// Offline-first mesh offload. Payloads are sealed with the device [SyncCrypto]
/// key before they sit in the queue. While P2P is disabled the queue stays on
/// device and peer status stays off.
class MeshOffloadSyncService {
  MeshOffloadSyncService({
    required SyncCrypto crypto,
    MeshPermissionGate? gate,
    this.deliver,
  }) : _crypto = crypto,
       _gate = gate ?? MeshPermissionGate();

  final SyncCrypto _crypto;
  final MeshPermissionGate _gate;

  /// Receives ciphertext only. Unused while the permission gate denies peers.
  final Future<void> Function(MeshOffloadRecord record)? deliver;

  final List<MeshOffloadRecord> _queue = [];

  List<MeshOffloadRecord> get pending => List.unmodifiable(_queue);

  Future<MeshOffloadEnqueueResult> enqueue({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final envelope = await _crypto.encryptJson(payload);
    _queue.add(MeshOffloadRecord(id: id, envelope: envelope));
    final peers = await _peerStatus();
    return MeshOffloadEnqueueResult(
      queued: true,
      peers: peers,
      sent: false,
    );
  }

  Future<MeshOffloadFlushResult> flush({bool offline = false}) async {
    final peers = await _peerStatus();
    final allowed = FreeTierGate.allowsMeshOffload(
      PremiumAccess.current,
      offline: offline,
    );
    if (!allowed || peers == PeerSyncStatus.off) {
      return MeshOffloadFlushResult(
        peers: peers,
        delivered: 0,
        retained: _queue.length,
      );
    }
    final sender = deliver;
    if (sender == null) {
      return MeshOffloadFlushResult(
        peers: PeerSyncStatus.waiting,
        delivered: 0,
        retained: _queue.length,
      );
    }
    final batch = List<MeshOffloadRecord>.from(_queue);
    _queue.clear();
    for (final record in batch) {
      await sender(record);
    }
    return MeshOffloadFlushResult(
      peers: PeerSyncStatus.idle,
      delivered: batch.length,
      retained: _queue.length,
    );
  }

  Future<PeerSyncStatus> _peerStatus() async {
    final decision = await _gate.evaluate();
    if (!decision.permitted) return PeerSyncStatus.off;
    return PeerSyncStatus.idle;
  }
}
