import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/auditable_personal_change_engine.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/product_value_delivery_ledger.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_save_experience_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/save_moment_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  const coordinator = PostSaveExperienceCoordinator();

  test('first save returns at most one validated observation', () {
    final entry = _entry(
      id: 'first',
      at: DateTime.utc(2026, 8, 1, 9),
      transcript: 'I checked the finished report again before sending it.',
      withObservation: true,
    );

    final result = coordinator.build(_saved(entry, [entry]));

    expect(result.kind, PostSaveExperienceKind.firstSave);
    expect(result.conclusion?.value.kind, ExplainableInsightKind.observation);
    expect(result.conclusion?.value.evidence, hasLength(1));
    expect(result.nextQuestion, contains('report'));
  });

  test('invalid stale offsets after transcript edit yield no conclusion', () {
    final original = _entry(
      id: 'first',
      at: DateTime.utc(2026, 8, 1, 9),
      transcript: 'I checked the finished report again before sending it.',
      withObservation: true,
    );
    final edited = original.copyWith(
      transcript: 'I sent the report as soon as it was ready.',
    );

    final result = coordinator.build(_saved(edited, [edited]));

    expect(result.kind, PostSaveExperienceKind.noConclusion);
    expect(result.conclusion, isNull);
    expect(result.nextQuestion, isNull);
  });

  test(
    'second related distinct save returns one validated possible change',
    () {
      final then = _entry(
        id: 'then',
        at: DateTime.utc(2025, 7, 31, 4),
        transcript:
            'I answered the work message immediately and felt worried about '
            'the deadline.',
      );
      final now = _entry(
        id: 'now',
        at: DateTime.utc(2025, 8, 1, 4),
        transcript:
            'I paused before answering the work message and felt calm about '
            'the deadline.',
      );

      final result = coordinator.build(_saved(now, [then, now]));

      expect(AuditablePersonalChangeEngine.areRelated(then, now), isTrue);
      expect(
        AuditablePersonalChangeEngine.buildEarlyComparison(
          entries: [then, now],
        ),
        isNotNull,
      );
      expect(result.kind, PostSaveExperienceKind.secondRelatedSave);
      expect(result.conclusion?.value.kind, ExplainableInsightKind.change);
      expect(
        result.conclusion!.value.evidence.map((item) => item.entryId).toSet(),
        {'then', 'now'},
      );
    },
  );

  test('unrelated second save does not produce a comparison', () {
    final then = _entry(
      id: 'then',
      at: DateTime.utc(2025, 7, 31, 4),
      transcript: 'I checked the project launch plan because I felt worried.',
    );
    final now = _entry(
      id: 'now',
      at: DateTime.utc(2025, 8, 1, 4),
      transcript: 'The garden tomatoes were ready and I cooked dinner.',
    );

    final result = coordinator.build(_saved(now, [then, now]));

    expect(result.kind, PostSaveExperienceKind.noConclusion);
    expect(result.conclusion, isNull);
  });

  test('commercial access policy does not deliver free comparison twice', () {
    final then = _entry(
      id: 'then',
      at: DateTime.utc(2025, 7, 31),
      transcript:
          'I answered the work message immediately and felt worried about '
          'the deadline.',
    );
    final now = _entry(
      id: 'now',
      at: DateTime.utc(2025, 8, 1),
      transcript:
          'I paused before answering the work message and felt calm about '
          'the deadline.',
    );
    const gated = PostSaveExperienceCoordinator(
      productValue: ProductValueState(
        generatedCapabilities: {CapabilityId.firstEarlyComparison},
      ),
    );

    final result = gated.build(_saved(now, [then, now]));

    expect(result.kind, PostSaveExperienceKind.noConclusion);
    expect(result.conclusion, isNull);
  });

  test('existing validated output remains readable after later saves', () {
    final first = _entry(
      id: 'first',
      at: DateTime.utc(2026, 7, 1),
      transcript: 'I prepared the report before the work review.',
    );
    final second = _entry(
      id: 'second',
      at: DateTime.utc(2026, 7, 2),
      transcript: 'I checked the report again before the work review.',
    );
    final current = _entry(
      id: 'third',
      at: DateTime.utc(2026, 7, 3),
      transcript: 'I checked the finished report again before sending it.',
      withObservation: true,
    );

    // Both free promises are already kept, so this is not a fresh delivery —
    // it is the artifact being read again, which must keep working.
    final delivered = const PostSaveExperienceCoordinator(
      deliveryLedger: ProductValueDeliveryLedger(
        policyVersion: MonetizationPolicy.policyVersion,
        firstValidObservationArtifactId: 'observation-earlier',
        firstValidComparisonArtifactId: 'comparison-earlier',
      ),
    );

    final result = delivered.build(_saved(current, [first, second, current]));

    expect(result.kind, PostSaveExperienceKind.returnSave);
    expect(result.conclusion?.value.id, 'observation-third');
  });

  test('an archived source cannot support a persisted comparison', () {
    final thenAt = DateTime.utc(2026, 7, 1);
    final nowAt = DateTime.utc(2026, 7, 8);
    const thenText =
        'I answered the work message immediately and felt worried about '
        'the deadline.';
    const nowText =
        'I paused before answering the work message and felt calm about '
        'the deadline.';
    final visibleThen = _entry(id: 'then', at: thenAt, transcript: thenText);
    final visibleNow = _entry(id: 'now', at: nowAt, transcript: nowText);
    final comparison = AuditablePersonalChangeEngine.buildEarlyComparison(
      entries: [visibleThen, visibleNow],
    )!.conclusion.value;
    final archivedThen = _entry(
      id: 'then',
      at: thenAt,
      transcript: thenText,
      isArchived: true,
    );
    final current = _entry(
      id: 'now',
      at: nowAt,
      transcript: nowText,
      conclusion: comparison,
    );

    final result = _deliveredCoordinator.build(
      _saved(current, [archivedThen, current]),
    );

    expect(result.kind, PostSaveExperienceKind.noConclusion);
    expect(result.conclusion, isNull);
  });

  test('contradicting evidence withholds a Then/Now comparison', () {
    final thenAt = DateTime.utc(2026, 7, 1);
    final nowAt = DateTime.utc(2026, 7, 8);
    const thenText =
        'I answered the work message immediately and felt worried about '
        'the deadline.';
    const nowText =
        'I paused before answering the work message and felt calm about '
        'the deadline.';
    final then = _entry(id: 'then', at: thenAt, transcript: thenText);
    final now = _entry(id: 'now', at: nowAt, transcript: nowText);
    final base = AuditablePersonalChangeEngine.buildEarlyComparison(
      entries: [then, now],
    )!.conclusion.value;
    final contradicted = base.copyWith(
      evidence: [
        ...base.evidence,
        TranscriptEvidenceCitation(
          entryId: then.id,
          quote: thenText,
          startUtf16: 0,
          endUtf16: thenText.length,
          role: TranscriptEvidenceRole.contradicting,
          sourceCapturedAt: thenAt,
          sourceType: EvidenceSourceType.voice,
        ),
      ],
    );
    final current = _entry(
      id: 'now',
      at: nowAt,
      transcript: nowText,
      conclusion: contradicted,
    );

    final result = _deliveredCoordinator.build(
      _saved(current, [then, current]),
    );

    expect(result.kind, PostSaveExperienceKind.noConclusion);
    expect(result.conclusion, isNull);
  });
}

const _deliveredCoordinator = PostSaveExperienceCoordinator(
  deliveryLedger: ProductValueDeliveryLedger(
    policyVersion: MonetizationPolicy.policyVersion,
    firstValidObservationArtifactId: 'observation-delivered',
    firstValidComparisonArtifactId: 'comparison-delivered',
  ),
);

SavedMomentResult _saved(JournalEntry entry, List<JournalEntry> entries) {
  return SavedMomentResult(
    entry: entry,
    entries: entries,
    analysisSucceeded: true,
    syncSucceeded: true,
  );
}

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  bool withObservation = false,
  bool isArchived = false,
  ExplainableConclusion? conclusion,
}) {
  final effectiveConclusion =
      conclusion ??
      (withObservation
          ? ExplainableConclusion(
              id: 'observation-$id',
              statement: 'You described checking the finished report again.',
              confidence: 60,
              reasoning: const [
                'The saved words describe checking the finished report again.',
              ],
              uncertaintyNote:
                  'One moment cannot show whether this response repeats.',
              evidence: [
                TranscriptEvidenceCitation(
                  entryId: id,
                  quote: transcript,
                  startUtf16: 0,
                  endUtf16: transcript.length,
                  role: TranscriptEvidenceRole.supporting,
                  sourceCapturedAt: at,
                  sourceType: EvidenceSourceType.voice,
                  audioVaultReference: 'vault-$id',
                  audioTimestampMs: 1200,
                  audioEndTimestampMs: 4400,
                ),
              ],
              alternatives: const [
                ExplainableAlternative(
                  statement: 'This may be specific to this one report.',
                  rationale:
                      'ArchiveMe has only one supporting saved moment so far.',
                ),
              ],
              provenance: ExplainableConclusionProvenance(
                source: 'test',
                generatedAt: at.add(const Duration(minutes: 1)),
                schemaVersion: ExplainableConclusion.schemaVersion,
              ),
              nextRecordingPrompt:
                  'When the report is ready next time, what do you do?',
            )
          : null);
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 20,
    localAudioVaultRef: 'vault-$id',
    isArchived: isArchived,
    archivedAt: isArchived ? at.add(const Duration(minutes: 2)) : null,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: transcript,
      concreteObservation: effectiveConclusion?.statement ?? '',
      repeatedSignal: '',
      explainableConclusion: effectiveConclusion,
    ),
  );
}
