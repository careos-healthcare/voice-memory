import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/memory_graph/spatial/quad_tree_spatial_index.dart';

void main() {
  group('QuadTreeSpatialIndex', () {
    test('inserts bounding boxes and rejects entries outside its bounds', () {
      final index = QuadTreeSpatialIndex<String>(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        nodeCapacity: 2,
      );

      expect(index.insert(const Rect.fromLTWH(10, 10, 5, 5), 'inside'), isTrue);
      expect(
        index.insert(const Rect.fromLTWH(120, 120, 5, 5), 'outside'),
        isFalse,
      );
      expect(index.length, 1);
    });

    test('returns intersecting entries without quadrant duplicates', () {
      final index = QuadTreeSpatialIndex<String>(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        nodeCapacity: 1,
      );
      index
        ..insert(const Rect.fromLTWH(5, 5, 8, 8), 'north-west')
        ..insert(const Rect.fromLTWH(80, 5, 8, 8), 'north-east')
        ..insert(const Rect.fromLTWH(45, 45, 20, 20), 'spanning')
        ..insert(const Rect.fromLTWH(80, 80, 8, 8), 'south-east');

      expect(index.query(const Rect.fromLTWH(0, 0, 55, 55)).toSet(), {
        'north-west',
        'spanning',
      });
      expect(index.query(const Rect.fromLTWH(40, 40, 30, 30)), ['spanning']);
    });

    test('culls a 10,000-item grid accurately within a frame budget', () {
      final index = QuadTreeSpatialIndex<int>(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
      );
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 100; x++) {
          final id = y * 100 + x;
          index.insert(Rect.fromLTWH(x * 10 + 1, y * 10 + 1, 4, 4), id);
        }
      }

      final viewport = const Rect.fromLTWH(200, 300, 100, 100);
      final warmup = index.query(viewport);
      expect(warmup, hasLength(100));
      final stopwatch = Stopwatch()..start();
      for (var iteration = 0; iteration < 200; iteration++) {
        expect(index.query(viewport), hasLength(100));
      }
      stopwatch.stop();

      final averageMicros = stopwatch.elapsedMicroseconds / 200;
      expect(
        averageMicros,
        lessThan(16600),
        reason: 'Viewport culling must stay inside a 16.6ms frame.',
      );
    });
  });
}
