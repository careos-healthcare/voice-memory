import 'dart:convert';

import 'package:archiveme_mobile/desktop/vault_sync_status.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/sync/mesh_offload_sync_service.dart';
import 'package:archiveme_mobile/services/mesh/mesh_permission_gate.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queues ciphertext locally and leaves peers off', () async {
    final crypto = SyncCrypto(List<int>.filled(32, 7));
    final service = MeshOffloadSyncService(crypto: crypto);

    final result = await service.enqueue(
      id: 'entry-1',
      payload: const {'body': 'rent is due'},
    );

    expect(result.queued, isTrue);
    expect(result.sent, isFalse);
    expect(result.peers, PeerSyncStatus.off);
    expect(result.peers.name, 'off');

    final stored = service.pending.single.envelope.ciphertext;
    expect(stored.contains('rent is due'), isFalse);
    expect(base64Decode(stored), isNotEmpty);

    final flush = await service.flush();
    expect(flush.peers, PeerSyncStatus.off);
    expect(flush.delivered, 0);
    expect(flush.retained, 1);

    final opened = await crypto.decryptJson(service.pending.single.envelope);
    expect(opened['body'], 'rent is due');
  });

  test('an offline flag does not send the mesh for a free account', () async {
    PremiumAccess.apply(PremiumEntitlement.free);
    final crypto = SyncCrypto(List<int>.filled(32, 7));
    final service = MeshOffloadSyncService(
      crypto: crypto,
      gate: MeshPermissionGate(
        meshFeatureEnabled: true,
        localNetworkPermission: FakeLocalNetworkPermissionGateway(
          granted: true,
        ),
      ),
    );
    await service.enqueue(id: 'entry-2', payload: const {'body': 'local'});

    final flush = await service.flush(offline: true);

    expect(flush.delivered, 0);
    expect(flush.retained, 1);
    PremiumAccess.apply(PremiumEntitlement.free);
  });
}
