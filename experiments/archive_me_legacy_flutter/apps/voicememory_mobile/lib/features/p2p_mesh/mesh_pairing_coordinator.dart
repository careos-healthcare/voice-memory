import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../services/security/mesh_identity_service.dart';
import '../../services/security/sync_identity_service.dart';
import 'mesh_secure_session.dart';
import 'mesh_trust_store.dart';

class MeshPairingCoordinator {
  MeshPairingCoordinator({
    required this.meshIdentity,
    required this.syncIdentity,
    required this.trustStore,
    Random? random,
  }) : _random = random ?? Random.secure();

  final MeshIdentityService meshIdentity;
  final SyncIdentityService syncIdentity;
  final MeshTrustStore trustStore;
  final Random _random;

  Future<MeshPairingInvitation> createInvitation({
    required String serviceId,
    Duration lifetime = const Duration(minutes: 2),
  }) async {
    if (lifetime <= Duration.zero || lifetime > const Duration(minutes: 5)) {
      throw ArgumentError.value(lifetime, 'lifetime');
    }
    final identity = await meshIdentity.identity();
    return MeshPairingInvitation(
      serviceId: serviceId,
      identityFingerprint: identity.fingerprint,
      oneTimeNonce: Uint8List.fromList(
        List.generate(32, (_) => _random.nextInt(256)),
      ),
      expiresAt: DateTime.now().toUtc().add(lifetime),
    );
  }

  Future<TrustedMeshPeer> confirmAndTrust(
    MeshPendingSession pending, {
    required String displayName,
  }) async {
    await pending.confirm();
    final remote =
        pending.transcript.initiator.deviceId == pending.remoteDeviceId
        ? pending.transcript.initiator
        : pending.transcript.responder;
    final peer = TrustedMeshPeer(
      deviceId: remote.deviceId,
      displayName: displayName.trim().isEmpty
          ? 'Paired ArchiveMe device'
          : displayName.trim(),
      fingerprint: pending.remoteFingerprint,
      identityPublicKey: remote.identityPublicKey,
      pairedAt: DateTime.now(),
    );
    await trustStore.trust(peer);
    return peer;
  }

  Future<void> sendSyncIdentity(MeshSecureSession session) async {
    if (!session.isPairingConfirmed) {
      throw StateError('Confirm the mesh pairing before transferring keys.');
    }
    final bundle = await syncIdentity.createMeshSessionPairingBundle();
    try {
      await session.send({
        'version': 1,
        'type': 'sync_identity',
        'bundle': base64Encode(bundle),
      });
    } finally {
      bundle.fillRange(0, bundle.length, 0);
    }
  }

  Future<void> receiveSyncIdentity(
    MeshSecureSession session, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!session.isPairingConfirmed) {
      throw StateError('Confirm the mesh pairing before accepting keys.');
    }
    final packet = await session.packets
        .firstWhere((value) => value['type'] == 'sync_identity')
        .timeout(timeout);
    final value = packet['bundle'];
    if (packet['version'] != 1 || value is! String) {
      throw const FormatException('Invalid mesh sync identity packet.');
    }
    final bytes = Uint8List.fromList(base64Decode(value));
    try {
      await syncIdentity.acceptMeshSessionPairingBundle(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<void> revoke(String deviceId) => trustStore.revoke(deviceId);
}
