import 'package:archiveme_mobile/features/post_save/post_save_repeat_copy.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_model.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostSaveRepeatCopy', () {
    test('uses generic copy for awkward generated phrase insight', () {
      final display = PostSaveRepeatCopy.resolve(
        const DailyMirrorResult(
          stage: DailyMirrorStage.possibleLoop,
          heroTitle: 'Repeat',
          heroBody: 'Both moments mention is test to see and test to see if.',
          evidenceLine: "You used the words 'is test to see'.",
          nextQuestion: 'Tomorrow, notice if "is test to see" shows up again.',
          primaryCta: 'Record',
          hasGroundedEvidence: true,
          hasChange: false,
          evidenceTerms: ['is test to see'],
          evidenceEntryIds: ['a', 'b'],
        ),
      );

      expect(display.show, isTrue);
      expect(display.body, PostSaveRepeatCopy.genericBody);
      expect(display.evidenceLine, isNull);
      expect(display.tomorrowLine, PostSaveRepeatCopy.genericTomorrow);
      expect(display.shownKind, 'generic');
      expect(display.confidence, lessThan(0.5));
    });

    test('keeps curated behavior loop copy with safe tomorrow line', () {
      final display = PostSaveRepeatCopy.resolve(
        const DailyMirrorResult(
          stage: DailyMirrorStage.possibleLoop,
          heroTitle: 'Loop',
          heroBody:
              'Pressure shows up, then you say yes before checking your capacity.',
          evidenceLine: "In your words: 'said yes' and 'no capacity'.",
          nextQuestion: 'Tomorrow, notice the moment before you agree.',
          primaryCta: 'Record',
          hasGroundedEvidence: true,
          hasChange: false,
          evidenceTerms: ['said yes', 'no capacity'],
          evidenceEntryIds: ['a', 'b'],
        ),
      );

      expect(display.show, isTrue);
      expect(
        display.body,
        'Pressure shows up, then you say yes before checking your capacity.',
      );
      expect(display.tomorrowLine, contains('Tomorrow'));
    });
  });
}