import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_model.dart';

void main() {
  test('notEnoughData when no funnel', () {
    final s = buildHookDiagnosisSummary(
      events: const [],
      checkInsCreated: 0,
      checkInsDueShown: 0,
      checkInsCompleted: 0,
    );
    expect(s.likelyFailure, HookLikelyFailure.notEnoughData);
  });

  test('questionNotCompelling when not useful and did not care', () {
    final s = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.notReally,
        ),
        HookDiagnosisEvent(
          id: '2',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInMissedReason,
          reason: HookDiagnosisMissedReason.didNotCare,
        ),
      ],
      checkInsCreated: 2,
      checkInsDueShown: 2,
      checkInsCompleted: 0,
    );
    expect(s.likelyFailure, HookLikelyFailure.questionNotCompelling);
  });

  test('reminderProblem when created high due shown low', () {
    final s = buildHookDiagnosisSummary(
      events: const [],
      checkInsCreated: 4,
      checkInsDueShown: 1,
      checkInsCompleted: 0,
    );
    expect(s.likelyFailure, HookLikelyFailure.reminderProblem);
  });

  test('comprehensionProblem when confusing', () {
    final s = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInMissedReason,
          reason: HookDiagnosisMissedReason.confusing,
        ),
      ],
      checkInsCreated: 3,
      checkInsDueShown: 3,
      checkInsCompleted: 0,
    );
    expect(s.likelyFailure, HookLikelyFailure.comprehensionProblem);
  });

  test('resultQualityProblem when completed but result not useful', () {
    final s = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInResultRated,
          rating: HookDiagnosisRating.notReally,
        ),
      ],
      checkInsCreated: 2,
      checkInsDueShown: 2,
      checkInsCompleted: 1,
    );
    expect(s.likelyFailure, HookLikelyFailure.resultQualityProblem);
  });

  test('working when completion and question ratings strong', () {
    final s = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.yes,
        ),
        HookDiagnosisEvent(
          id: '2',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.sortOf,
        ),
      ],
      checkInsCreated: 5,
      checkInsDueShown: 5,
      checkInsCompleted: 2,
    );
    expect(s.likelyFailure, HookLikelyFailure.working);
  });

  test('usefulQuestionRate and dominantFailureReason', () {
    final s = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.yes,
        ),
        HookDiagnosisEvent(
          id: '2',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.sortOf,
        ),
        HookDiagnosisEvent(
          id: '3',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.notReally,
        ),
        HookDiagnosisEvent(
          id: '4',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInMissedReason,
          reason: HookDiagnosisMissedReason.didNotCare,
        ),
        HookDiagnosisEvent(
          id: '5',
          createdAt: DateTime(2026, 5, 25),
          type: HookDiagnosisEventType.checkInMissedReason,
          reason: HookDiagnosisMissedReason.didNotCare,
        ),
      ],
      checkInsCreated: 2,
      checkInsDueShown: 2,
      checkInsCompleted: 0,
    );
    expect(s.usefulQuestionRate, closeTo(2 / 3, 0.01));
    expect(s.dominantFailureReason, 'didNotCare');
  });

  test('dominantFailureReason is none with no negatives', () {
    final s = buildHookDiagnosisSummary(
      events: const [],
      checkInsCreated: 1,
      checkInsDueShown: 1,
      checkInsCompleted: 1,
    );
    expect(s.usefulQuestionRate, isNull);
    expect(s.dominantFailureReason, 'none');
  });

  test('notUsefulReasonCounts and clarityIssueRate', () {
    final s = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInResultNotUsefulReason,
          reason: HookDiagnosisNotUsefulReason.tooVague,
        ),
      ],
      checkInsCreated: 2,
      checkInsDueShown: 2,
      checkInsCompleted: 1,
      examplesOpenedCount: 1,
    );
    expect(s.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.tooVague], 1);
    expect(s.examplesOpenedCount, 1);
    expect(s.clarityIssueRate, closeTo(1.0, 0.01));
  });
}
