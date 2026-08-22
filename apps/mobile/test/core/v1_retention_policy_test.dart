import 'package:archiveme_mobile/core/config/v1_retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V1RetentionPolicy', () {
    test('V1-only mode quarantines retention surfaces', () {
      expect(V1RetentionPolicy.enableV1Only, isTrue);
      expect(V1RetentionPolicy.quarantineClinicalConsumerSignals, isTrue);
      expect(V1RetentionPolicy.hideProminentStreakUi, isTrue);
      expect(V1RetentionPolicy.showCapacityReturnTriggers, isFalse);
      expect(V1RetentionPolicy.showCuriosityPostSaveHooks, isFalse);
      expect(V1RetentionPolicy.showAdvancedRetentionPostSave, isFalse);
      expect(V1RetentionPolicy.requireEvidenceAnchoredHooks, isTrue);
    });
  });
}