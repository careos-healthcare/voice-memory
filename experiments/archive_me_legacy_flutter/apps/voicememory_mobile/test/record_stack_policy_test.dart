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
    test('uses clean empty state without first recording handoff', () {
      final d = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: true,
        reflectionCount: 0,
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
      expect(d.showFirstRecordingHandoff, isFalse);
      expect(d.showFramingTitle, isFalse);
      expect(d.showFirstThreeJourney, isFalse);
      expect(d.showStarterPrompts, isFalse);
      expect(d.suppressDuplicateRecordCtas, isFalse);
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
    test('V1 hides the post-V1 objective card', () {
      final empty = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: true,
        reflectionCount: 0,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(empty.showFirstRecordingHandoff, isFalse);
      expect(empty.showCurrentObjectiveCard, isFalse);

      final one = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        reflectionCount: 1,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(one.showCurrentObjectiveCard, isFalse);

      final two = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        reflectionCount: 2,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(two.showCurrentObjectiveCard, isFalse);
    });
  });

  group('entry count gates', () {
    test('progress cards stay hidden until entry count loads', () {
      final loading = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        reflectionCount: 0,
        entryCountLoaded: false,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(loading.showFirstThreeJourney, isFalse);
      expect(loading.showStarterPrompts, isFalse);
      expect(loading.showCurrentObjectiveCard, isFalse);
      expect(loading.showActivePatternThread, isFalse);
    });

    test('first-three journey only at two entries', () {
      final two = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        reflectionCount: 2,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(two.showFirstThreeJourney, isTrue);
      expect(two.showStarterPrompts, isFalse);

      final three = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        reflectionCount: 3,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(three.showFirstThreeJourney, isFalse);
      expect(three.showStarterPrompts, isTrue);
    });

    test('two loaded entries enable first-three journey card', () {
      final two = decideRecordStack(
        hasDueCheck: false,
        isFirstRun: false,
        reflectionCount: 2,
        entryCountLoaded: true,
        isTrialMode: false,
        isRecording: false,
        hasSavedReflection: false,
        inputQualityNeedsCoach: false,
        hasCompletedResult: false,
        hasResultNextCheck: false,
        hasRoutineAnchorOffer: false,
        hasArchiveProof: false,
      );
      expect(two.showFirstThreeJourney, isTrue);
      expect(two.showStarterPrompts, isFalse);
    });
  });
}
