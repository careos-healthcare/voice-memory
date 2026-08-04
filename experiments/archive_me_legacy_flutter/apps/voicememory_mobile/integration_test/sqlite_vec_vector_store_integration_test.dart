import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native sqlite-vec KNN and metadata filters roundtrip', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'sqlite_vec_integration_',
    );
    final store = await SqliteVecVectorStore.open(
      databasePath: '${directory.path}/vectors.sqlite3',
      dimensions: 3,
    );
    addTearDown(() async {
      store.close();
      await directory.delete(recursive: true);
    });
    expect(store.isAccelerated, isTrue, reason: store.unavailableReason);
    store.replaceAll([
      SqliteVecRecord(
        entryId: 'goal-exact',
        embedding: Float32List.fromList([1, 0, 0]),
        clusterType: 'goal',
        updatedAt: DateTime.utc(2026, 7),
        confidence: .95,
        nodeIds: const ['goal-node'],
        tags: const {'goal'},
      ),
      SqliteVecRecord(
        entryId: 'person-exact',
        embedding: Float32List.fromList([1, 0, 0]),
        clusterType: 'person',
        updatedAt: DateTime.utc(2026, 7),
        confidence: .95,
        nodeIds: const ['person-node'],
        tags: const {'person'},
      ),
      SqliteVecRecord(
        entryId: 'goal-orthogonal',
        embedding: Float32List.fromList([0, 1, 0]),
        clusterType: 'goal',
        updatedAt: DateTime.utc(2024),
        confidence: .4,
        nodeIds: const ['old-goal-node'],
        tags: const {'goal'},
      ),
    ]);

    final hits = store.search(
      Float32List.fromList([1, 0, 0]),
      clusterType: 'goal',
      updatedAfter: DateTime.utc(2026),
      minimumConfidence: .8,
    );

    expect(hits, hasLength(1));
    expect(hits.single.entryId, 'goal-exact');
    expect(hits.single.distance, closeTo(0, .0001));
    expect(hits.single.nodeIds, ['goal-node']);
  });
}
