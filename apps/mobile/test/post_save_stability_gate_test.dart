import 'package:archiveme_mobile/features/post_save/post_save_stability_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostSaveStabilityGate', () {
    test('skips archive cards for first two entries', () {
      expect(
        PostSaveStabilityGate.shouldSkipArchiveCards(entryCount: 1),
        isTrue,
      );
      expect(
        PostSaveStabilityGate.shouldSkipArchiveCards(entryCount: 2),
        isTrue,
      );
      expect(
        PostSaveStabilityGate.shouldSkipArchiveCards(entryCount: 3),
        isFalse,
      );
    });
  });
}