import 'dart:typed_data';

import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/storage/sqlite/embedding_blob_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _blob(List<double> values) {
  return Float32List.fromList(values).buffer.asUint8List();
}

void main() {
  tearDown(() {
    IsolateComputeJob.debugForceInline = false;
    IsolateJobTrace.reset();
  });

  test('ranks cosine-similar blobs first', () {
    final hits = rankEmbeddingBlobs(
      EmbeddingBlobRankInput(
        queryEmbedding: const [1, 0],
        rows: [
          EmbeddingBlobRow(entryId: 'far', blob: _blob(const [0, 1])),
          EmbeddingBlobRow(entryId: 'near', blob: _blob(const [0.9, 0.1])),
        ],
        limit: 1,
      ),
    );

    expect(hits, hasLength(1));
    expect(hits.single.entryId, 'near');
    expect(hits.single.cosineSimilarity, greaterThan(0.9));
  });

  test('forceIsolate path records a debug duration', () async {
    IsolateJobTrace.captureEvents = true;

    final hits = await EmbeddingBlobRanker.rank(
      queryEmbedding: const [1, 0, 0],
      rows: [
        EmbeddingBlobRow(entryId: 'a', blob: _blob(const [1, 0, 0])),
        EmbeddingBlobRow(entryId: 'b', blob: _blob(const [0, 1, 0])),
      ],
      limit: 2,
      forceIsolate: true,
    );

    expect(hits.first.entryId, 'a');
    expect(
      IsolateJobTrace.events.any(
        (event) => event.label == 'sqlite.vec.blob_rank',
      ),
      isTrue,
    );
  });
}
