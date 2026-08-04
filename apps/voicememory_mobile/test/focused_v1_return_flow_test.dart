import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/changes/change_thread_projection.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_save_experience_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/save_moment_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

void main() {
  test('authoritative first-save to corrected Changes return flow', () {
    final firstAt = DateTime.utc(2026, 7, 24, 9);
    final secondAt = DateTime.utc(2026, 7, 31, 9);
    const firstText =
        'I answered the work message immediately and felt worried about '
        'the deadline.';
    const secondText =
        'I paused before answering the work message and felt calm about '
        'the deadline.';
    final observation = _observation(firstText, firstAt);
    final first = _entry('first', firstText, firstAt, conclusion: observation);
    final freeCoordinator = PostSaveExperienceCoordinator.forSubscription(
      SubscriptionState.free(),
    );

    final firstExperience = freeCoordinator.build(
      SavedMomentResult(
        entry: first,
        entries: [first],
        analysisSucceeded: true,
        syncSucceeded: true,
      ),
    );
    expect(firstExperience.kind, PostSaveExperienceKind.firstSave);
    expect(
      firstExperience.conclusion?.value.kind,
      ExplainableInsightKind.observation,
    );
    expect(firstExperience.conclusion?.value.evidence.single.quote, firstText);

    final correction = InsightFeedbackRecord(
      insightId: observation.id,
      insightType: InsightFeedbackType.auditableConclusion,
      choice: InsightFeedbackChoice.wrongAngle,
      createdAt: firstAt.add(const Duration(minutes: 2)),
      sourceRoute: 'record_post_save',
      templateId: observation.theoryId,
      conclusionKind: observation.kind.name,
      evidenceEntryIds: const ['first'],
      correctionNote: 'The deadline, not checking, was the important part.',
    );
    final afterRestart = freeCoordinator.build(
      SavedMomentResult(
        entry: first,
        entries: [first],
        analysisSucceeded: true,
        syncSucceeded: true,
      ),
      feedback: [correction],
    );
    expect(afterRestart.conclusion, isNull);
    expect(first.transcript, firstText);

    final second = _entry('second', secondText, secondAt);
    final secondExperience = freeCoordinator.build(
      SavedMomentResult(
        entry: second,
        entries: [first, second],
        analysisSucceeded: true,
        syncSucceeded: true,
      ),
      feedback: [correction],
    );
    expect(secondExperience.kind, PostSaveExperienceKind.secondRelatedSave);
    expect(
      secondExperience.conclusion?.value.kind,
      ExplainableInsightKind.change,
    );
    final evidence = secondExperience.conclusion!.value.evidence;
    expect(evidence.map((item) => item.entryId).toSet(), {'first', 'second'});
    expect(evidence.first.temporalRole, EvidenceTemporalRole.then);
    expect(evidence.last.temporalRole, EvidenceTemporalRole.now);

    final projection = ChangeThreadProjector.project(
      archiveId: 'local',
      entries: [first, second],
      conclusions: [secondExperience.conclusion!.value],
      feedback: [correction],
    );
    expect(projection.threads, hasLength(1));
    final thread = projection.threads.single;
    expect(thread.events.single.conclusionKind, ExplainableInsightKind.change);
    expect(thread.thread.firstObservedAt, firstAt);
    expect(thread.thread.latestObservedAt, secondAt);

    const expired = EntitlementSnapshot(
      plan: PlanKind.pro,
      status: EntitlementStatus.expired,
    );
    expect(
      AccessPolicyEngine.decide(
        capability: CapabilityId.readExistingGeneratedOutput,
        entitlement: expired,
      ).allowed,
      isTrue,
    );
    expect(
      AccessPolicyEngine.decide(
        capability: CapabilityId.ongoingComparisons,
        entitlement: expired,
        usage: const UsageSnapshot(
          allowances: {UsageMeterId.ongoingComparisonGeneration: 1},
        ),
      ).allowed,
      isFalse,
    );
  });
}

JournalEntry _entry(
  String id,
  String transcript,
  DateTime createdAt, {
  ExplainableConclusion? conclusion,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 0,
  source: SavedMomentSource.typed,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
    explainableConclusion: conclusion,
  ),
);

ExplainableConclusion _observation(String transcript, DateTime capturedAt) =>
    ExplainableConclusion(
      id: 'first-observation',
      statement: 'You described the work message and the deadline.',
      confidence: 60,
      reasoning: const [
        'The saved words describe the work message and the deadline.',
      ],
      uncertaintyNote: 'One moment cannot show whether this response repeats.',
      evidence: [
        TranscriptEvidenceCitation(
          entryId: 'first',
          quote: transcript,
          startUtf16: 0,
          endUtf16: transcript.length,
          role: TranscriptEvidenceRole.supporting,
          sourceCapturedAt: capturedAt,
          sourceType: EvidenceSourceType.text,
          confidenceScore: 0.7,
        ),
      ],
      alternatives: const [
        ExplainableAlternative(
          statement: 'This may be specific to this one work moment.',
          rationale: 'One moment cannot establish a repeated response.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'test',
        generatedAt: capturedAt.add(const Duration(minutes: 1)),
        schemaVersion: ExplainableConclusion.schemaVersion,
      ),
      kind: ExplainableInsightKind.observation,
      nextRecordingPrompt:
          'When this work message comes up again, what happens before you '
          'answer?',
      theoryId: 'first_observation_v1',
    );
