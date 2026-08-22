import 'package:archiveme_mobile/features/post_save/post_save_archive_hierarchy.dart';
import 'package:archiveme_mobile/features/post_save/post_save_repeat_ui_gates.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_model.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostSaveRepeatUiGates', () {
    const groundedLoop = DailyMirrorResult(
      stage: DailyMirrorStage.possibleLoop,
      heroTitle: 'Loop',
      heroBody: 'Pressure shows up, then you say yes before checking capacity.',
      evidenceLine: "In your words: 'said yes'.",
      nextQuestion: 'Tomorrow, notice the moment before you agree.',
      primaryCta: 'Record',
      hasGroundedEvidence: true,
      hasChange: false,
      evidenceTerms: ['said yes'],
      evidenceEntryIds: ['a', 'b'],
    );

    test('suppresses noisy stack for grounded possible loop discovery', () {
      expect(
        PostSaveRepeatUiGates.suppressNoisyRepeatPostSaveCards(
          suppressNoisyFirstSaveCards: false,
          showFirstProofMoment: false,
          postSaveArchiveKind: PostSavePrimaryArchiveKind.discovery,
          mirror: groundedLoop,
        ),
        isTrue,
      );
    });

    test('does not suppress first-save calm state', () {
      expect(
        PostSaveRepeatUiGates.suppressNoisyRepeatPostSaveCards(
          suppressNoisyFirstSaveCards: true,
          showFirstProofMoment: false,
          postSaveArchiveKind: PostSavePrimaryArchiveKind.discovery,
          mirror: groundedLoop,
        ),
        isFalse,
      );
    });

    test('does not suppress first-proof payoff path', () {
      expect(
        PostSaveRepeatUiGates.suppressNoisyRepeatPostSaveCards(
          suppressNoisyFirstSaveCards: false,
          showFirstProofMoment: true,
          postSaveArchiveKind: PostSavePrimaryArchiveKind.discovery,
          mirror: groundedLoop,
        ),
        isFalse,
      );
    });

    test('does not suppress what-changed discovery', () {
      expect(
        PostSaveRepeatUiGates.suppressNoisyRepeatPostSaveCards(
          suppressNoisyFirstSaveCards: false,
          showFirstProofMoment: false,
          postSaveArchiveKind: PostSavePrimaryArchiveKind.discovery,
          mirror: const DailyMirrorResult(
            stage: DailyMirrorStage.whatChanged,
            heroTitle: 'Changed',
            heroBody: 'Something shifted.',
            primaryCta: 'Record',
            hasGroundedEvidence: true,
            hasChange: true,
            evidenceTerms: [],
            evidenceEntryIds: [],
          ),
        ),
        isFalse,
      );
    });
  });
}