import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';

void main() {
  late Directory directory;
  late SqliteVecVectorStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sqlite_vec_store_');
    store = await SqliteVecVectorStore.open(
      databasePath: '${directory.path}/vectors.sqlite3',
      dimensions: 3,
    );
  });

  tearDown(() async {
    store.close();
    await directory.delete(recursive: true);
  });

  test('sorts cosine distance in native vec0 KNN order', () {
    if (!store.isAccelerated) {
      markTestSkipped(
        'sqlite-vec is bundled into app targets, not the flutter_tester host: '
        '${store.unavailableReason}',
      );
      return;
    }
    store.replaceAll([
      _record('exact', [1, 0, 0], cluster: 'goal'),
      _record('near', [.8, .2, 0], cluster: 'goal'),
      _record('orthogonal', [0, 1, 0], cluster: 'person'),
    ]);

    final hits = store.search(Float32List.fromList([1, 0, 0]), limit: 3);

    expect(hits.map((hit) => hit.entryId), ['exact', 'near', 'orthogonal']);
    expect(hits.first.distance, closeTo(0, 0.0001));
    expect(hits[1].distance, lessThan(hits[2].distance));
  });

  test('roundtrips typed metadata and applies hybrid filters in vec0', () {
    if (!store.isAccelerated) {
      markTestSkipped(
        'sqlite-vec is bundled into app targets, not the flutter_tester host: '
        '${store.unavailableReason}',
      );
      return;
    }
    store.replaceAll([
      _record(
        'old-goal',
        [1, 0, 0],
        cluster: 'goal',
        confidence: .9,
        updatedAt: DateTime.utc(2025),
      ),
      _record(
        'current-goal',
        [.9, .1, 0],
        cluster: 'goal',
        confidence: .8,
        updatedAt: DateTime.utc(2026, 7),
      ),
      _record(
        'current-person',
        [1, 0, 0],
        cluster: 'person',
        confidence: .95,
        updatedAt: DateTime.utc(2026, 7),
      ),
    ]);

    final hits = store.search(
      Float32List.fromList([1, 0, 0]),
      limit: 5,
      clusterType: 'goal',
      updatedAfter: DateTime.utc(2026),
      minimumConfidence: .75,
    );

    expect(hits, hasLength(1));
    expect(hits.single.entryId, 'current-goal');
    expect(hits.single.clusterType, 'goal');
    expect(hits.single.confidence, closeTo(.8, .001));
    expect(hits.single.nodeIds, ['node-current-goal']);
    expect(hits.single.tags, {'goal', 'test'});
  });
}

SqliteVecRecord _record(
  String id,
  List<double> vector, {
  required String cluster,
  double confidence = 1,
  DateTime? updatedAt,
}) => SqliteVecRecord(
  entryId: id,
  embedding: Float32List.fromList(vector),
  clusterType: cluster,
  updatedAt: updatedAt ?? DateTime.utc(2026, 7, 27),
  confidence: confidence,
  nodeIds: ['node-$id'],
  tags: {cluster, 'test'},
);
