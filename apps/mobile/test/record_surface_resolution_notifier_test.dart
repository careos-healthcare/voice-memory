import 'package:archiveme_mobile/features/recording/record_surface_input_cache_key.dart';
import 'package:archiveme_mobile/features/recording/record_surface_resolution_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'record_surface_test_fixtures.dart';

void main() {
  group('RecordSurfaceResolutionNotifier', () {
    test('returns cached view state when input is unchanged', () {
      final notifier = RecordSurfaceResolutionNotifier();
      final input = emptyRecordSurfaceInput();

      final first = notifier.resolve(input);
      final second = notifier.resolve(input);

      expect(identical(first, second), isTrue);
    });

    test('recomputes when entry count changes', () {
      final notifier = RecordSurfaceResolutionNotifier();
      final first = notifier.resolve(emptyRecordSurfaceInput());
      final second = notifier.resolve(emptyRecordSurfaceInput(entryCount: 1));

      expect(identical(first, second), isFalse);
    });

    test('invalidate clears cached view state', () {
      final notifier = RecordSurfaceResolutionNotifier();
      final input = emptyRecordSurfaceInput();
      final first = notifier.resolve(input);
      notifier.invalidate();
      final second = notifier.resolve(input);

      expect(identical(first, second), isFalse);
    });
  });

  group('RecordSurfaceInputCacheKey', () {
    test('same input produces equal cache keys', () {
      final input = emptyRecordSurfaceInput();
      expect(
        RecordSurfaceInputCacheKey.from(input),
        RecordSurfaceInputCacheKey.from(input),
      );
    });
  });
}