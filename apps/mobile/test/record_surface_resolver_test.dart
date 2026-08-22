import 'package:archiveme_mobile/features/recording/record_surface_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'record_surface_test_fixtures.dart';

void main() {
  group('RecordSurfaceResolver', () {
    test('resolve returns view state for empty ready surface', () {
      final surface = RecordSurfaceResolver.resolve(emptyRecordSurfaceInput());

      expect(surface.canRecord, isTrue);
      expect(surface.showFraming, isTrue);
      expect(surface.firstUseSimplifiedRecord, isTrue);
      expect(surface.stack.showFirstRecordingHandoff, isFalse);
    });

    test('resolve is pure and does not require BuildContext', () {
      expect(RecordSurfaceResolver.resolve, isNotNull);
      expect(
        () => RecordSurfaceResolver.resolve(emptyRecordSurfaceInput()),
        returnsNormally,
      );
    });
  });
}