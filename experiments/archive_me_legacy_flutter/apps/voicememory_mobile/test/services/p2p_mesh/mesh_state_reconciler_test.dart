import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/services/p2p_mesh/mesh_state_reconciler.dart';

void main() {
  test('uses canonical empty-clock conflict semantics', () {
    expect(
      compareVectorClocks(const {}, const {}),
      MeshVectorClockRelation.concurrent,
    );
  });

  test('concurrent LWW edits converge deterministically on every peer', () {
    final first = _reconciler('anchor');
    final second = _reconciler('mobile');
    addTearDown(() {
      first.store.close();
      second.store.close();
    });
    final anchorEdit = first.write(
      kind: MeshCrdtEntityKind.graphNode,
      entityId: 'node-1',
      payload: const {'id': 'node-1', 'label': 'Anchor title'},
    );
    final mobileEdit = second.write(
      kind: MeshCrdtEntityKind.graphNode,
      entityId: 'node-1',
      payload: const {'id': 'node-1', 'label': 'Mobile title'},
    );

    first.merge([mobileEdit]);
    second.merge([anchorEdit]);

    expect(first.heads.single.payload, second.heads.single.payload);
    expect(first.heads.single.deviceId, 'mobile');
  });

  test('dominating vector clock wins and delta export is incremental', () {
    final anchor = _reconciler('anchor');
    final mobile = _reconciler('mobile');
    addTearDown(() {
      anchor.store.close();
      mobile.store.close();
    });
    final original = anchor.write(
      kind: MeshCrdtEntityKind.vectorMetadata,
      entityId: 'vector-1',
      payload: const {'entryId': 'vector-1', 'clusterType': 'memory'},
    );
    mobile.merge([original]);
    final updated = mobile.write(
      kind: MeshCrdtEntityKind.vectorMetadata,
      entityId: 'vector-1',
      payload: const {'entryId': 'vector-1', 'clusterType': 'topic'},
    );

    final result = anchor.merge([updated]);

    expect(result.applied, 1);
    expect(anchor.heads.single.payload?['clusterType'], 'topic');
    expect(anchor.deltaSince(const {'anchor': 1, 'mobile': 0}), [updated]);
    expect(
      compareVectorClocks(updated.vectorClock, original.vectorClock),
      MeshVectorClockRelation.dominates,
    );
  });
}

MeshStateReconciler _reconciler(String deviceId) {
  final database = sqlite3.openInMemory();
  final store = SqliteMeshCrdtStore(
    database: database,
    codec: EncryptedSqliteTextCodec(
      () => Uint8List.fromList(List<int>.filled(32, 7)),
    ),
    ownsDatabase: true,
  );
  return MeshStateReconciler(
    deviceId: deviceId,
    store: store,
    clock: () => DateTime.utc(2026, 7, 29, 8),
  );
}
