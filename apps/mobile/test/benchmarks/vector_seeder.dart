import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';

/// Builds normalized 384-d float32 vectors and the journal payload beside each.
///
/// One [SyntheticVectorBuffer] is filled in place for every row. Call
/// [release] after a pass so that buffer is zeroed. Database writes go through
/// [BenchmarkSeederIsolate], which repeats this fill inside a background
/// isolate and commits every [benchmarkSeedBatchSize] rows.
class VectorSeeder {
  VectorSeeder({this.dimensions = benchmarkEmbeddingDimensions})
    : buffer = SyntheticVectorBuffer(dimensions: dimensions);

  final int dimensions;
  final SyntheticVectorBuffer buffer;

  /// Overwrites [buffer] with entry [index] and returns its payload.
  SyntheticEntryPayload row(int index) {
    buffer.fill(index);
    return syntheticEntryPayload(index);
  }

  /// Visits [count] rows without keeping a vector list.
  void generate(
    int count,
    void Function(int index, SyntheticEntryPayload payload) onRow,
  ) {
    for (var index = 0; index < count; index++) {
      buffer.fill(index);
      onRow(index, syntheticEntryPayload(index));
    }
    release();
  }

  Float32List copyCurrent() => Float32List.fromList(buffer.values);

  void release() {
    buffer.release();
  }
}
