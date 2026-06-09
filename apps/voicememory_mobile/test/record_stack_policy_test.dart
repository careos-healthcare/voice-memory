import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/record/record_stack_policy.dart';

void main() {
  group('due check priority', () {
    test('due check suppresses first-run guidance', () {
      final d = decideRecordStack(
        hasDueCheck: true,
        isFirstRun: true,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(d.primaryState, RecordPrimaryState.dueCheck);
      expect(d.showDueCheckCard, isTrue);
      expect(d.showFirstRecordingHandoff, isFalse);
      expect(d.showTrialFirstMomentCard, isFalse);
      expect(d.showStarterPrompts, isFalse);
    });
  });

  group('first run', () {
    test('shows one dominant first recording handoff CTA', () {
      final d = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: true,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(d.primaryState, RecordPrimaryState.firstRun);
      expect(d.showFirstRecordingHandoff, isTrue);
      expect(d.showArchiveMemoryDemo, isFalse);
      expect(d.showTrialFirstMomentCard, isFalse);
      expect(d.showStarterPrompts, isFalse);
      expect(d.suppressDuplicateRecordCtas, isTrue);
    });

    test('trial mode shows trial first moment card', () {
      final d = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: true,
        isTrialMode: true,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(d.showFirstRecordingHandoff, isFalse);
      expect(d.showTrialFirstMomentCard, isTrue);
      expect(d.suppressDuplicateRecordCtas, isTrue);
    });
  });

  group('return-day journey', () {
    test('return-day card suppresses objective and starter prompts', () {
      final d = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
        showReturnDayJourney: true,
      );
      expect(d.showReturnDayJourneyCard, isTrue);
      expect(d.showStarterPrompts, isFalse);
      expect(d.showCurrentObjectiveCard, isFalse);
      expect(d.showFirstThreeJourney, isFalse);
    });
  });

  group('post save ordering', () {
    test('input quality coach appears before result cards', () {
      final d = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: true,
        inputQualityNeedsCoach: true,
        hasCompletedResult: true,
        hasResultNextCheck: true,
        hasRoutineAnchorOffer: true,
        hasArchiveProof: true,
      );
      expect(d.primaryState, RecordPrimaryState.postSaveNeedsInputQuality);
      expect(d.showInputQualityCoach, isTrue);
      expect(d.showCompletedResult, isFalse);
      expect(d.showArchiveProofCards, isFalse);
    });
  });

  group('current objective card', () {
    test('first recording handoff suppresses objective', () {
      final d = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: true,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(d.showFirstRecordingHandoff, isTrue);
      expect(d.showCurrentObjectiveCard, isFalse);
    });
  });
}
