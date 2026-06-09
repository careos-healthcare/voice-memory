import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/input_quality/input_quality_engine.dart';
import 'package:voicememory_mobile/features/input_quality/input_quality_model.dart';

void main() {
  group('weak input is detected', () {
    test('too short input is flagged and asks for sharpening', () {
      final r = assessReflectionQuality('ok');
      expect(r.level, InputQualityLevel.tooShort);
      expect(r.issues, contains(InputQualityIssue.tooShort));
      expect(r.shouldAskForSharpening, isTrue);
    });

    test('vague stress is flagged as too general', () {
      final r = assessReflectionQuality('Today was stressful.');
      expect(r.issues, contains(InputQualityIssue.tooGeneral));
      expect(r.shouldAskForSharpening, isTrue);
      expect(r.score, lessThan(0.5));
    });

    test('unclear "it was weird" is flagged as an unclear reference', () {
      final r = assessReflectionQuality('it was weird');
      expect(r.issues, contains(InputQualityIssue.unclearReference));
      expect(r.shouldAskForSharpening, isTrue);
    });

    test('mood-only input has no moment and no action', () {
      final r = assessReflectionQuality('I was tired.');
      expect(r.issues, contains(InputQualityIssue.noMoment));
      expect(r.issues, contains(InputQualityIssue.noFeelingOrAction));
      expect(r.shouldAskForSharpening, isTrue);
    });
  });

  group('strong input is recognised', () {
    test('"said yes before checking what I needed" is strong', () {
      final r =
          assessReflectionQuality('I said yes before checking what I needed.');
      expect(r.level, InputQualityLevel.strong);
      expect(r.score, greaterThanOrEqualTo(0.75));
      expect(r.shouldAskForSharpening, isFalse);
    });

    test('"worry came back when things got quiet" is strong', () {
      final r = assessReflectionQuality(
        'The worry came back when things got quiet.',
      );
      expect(r.level, InputQualityLevel.strong);
      expect(r.shouldAskForSharpening, isFalse);
    });

    test('avoidance moment with a reason is not coached', () {
      final r = assessReflectionQuality(
        'I avoided the message because I did not want pressure.',
      );
      expect(r.shouldAskForSharpening, isFalse);
      expect(r.score, greaterThanOrEqualTo(0.5));
    });
  });

  group('coaching copy', () {
    test('too short prompt asks for one moment', () {
      final r = assessReflectionQuality('ok');
      expect(r.helpfulPrompt, 'Add one moment from today.');
    });

    test('vague stress offers a pressure example rewrite', () {
      final r = assessReflectionQuality('Today was stressful.');
      expect(
        r.exampleRewrite,
        'I felt pressure when I was asked to help before I had time.',
      );
    });

    test('tired offers a tired example rewrite', () {
      final r = assessReflectionQuality('I was tired.');
      expect(r.exampleRewrite, 'I felt tired before saying yes again.');
    });
  });
}
