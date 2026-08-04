import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:voicememory_mobile/features/monetization/data/product_value_delivery_ledger_store.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/product_value_delivery_ledger.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_save_experience_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/save_moment_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory directory;
  late List<int> sharedKey;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('value_delivery_test_');
    sharedKey = List<int>.generate(32, (index) => index + 1);
  });

  tearDown(() => directory.delete(recursive: true));

  ProductValueDeliveryLedgerStore store({
    String archiveId = 'local',
    String file = 'ledger.enc',
  }) => ProductValueDeliveryLedgerStore(
    file: File('${directory.path}/$file'),
    keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: sharedKey),
    archiveId: archiveId,
    clock: () => DateTime.utc(2026, 8, 2),
  );

  group('ProductValueDeliveryGate', () {
    test('failed generation does not consume free proof', () async {
      final ledger = store();

      final outcome = await ledger.recordDelivered(
        const ProductValueDeliveryAttempt.generationFailed(),
      );

      expect(outcome.consumedFreeProof, isFalse);
      expect(outcome.rejection, ProductValueDeliveryRejection.generationFailed);
      expect(
        (await ledger.read()).hasDelivered(DeliveredValueKind.observation),
        isFalse,
      );
    });

    test('network error does not consume free proof', () async {
      final ledger = store();
      // A transport failure reaches this boundary as a generation that never
      // produced a candidate, and the free slot must survive it.
      final offline = await ledger.recordDelivered(
        _attempt(candidate: null, generationSucceeded: false),
      );
      expect(offline.consumedFreeProof, isFalse);

      final recovered = await ledger.recordDelivered(
        _attempt(candidate: _observation(), generationSucceeded: true),
      );

      expect(recovered.consumedFreeProof, isTrue);
      expect(
        (await ledger.read()).firstValidObservationArtifactId,
        'observation-report',
      );
    });

    test('invalid output does not consume free proof', () async {
      final ledger = store();

      final outcome = await ledger.recordDelivered(
        _attempt(candidate: _observationWithStaleOffsets()),
      );

      expect(outcome.consumedFreeProof, isFalse);
      expect(
        outcome.rejection,
        ProductValueDeliveryRejection.exactEvidenceValidationFailed,
      );
      expect((await ledger.read()).deliveredArtifactIds, isEmpty);
    });

    test(
      'semantically unsupported output does not consume free proof',
      () async {
        final ledger = store();

        final outcome = await ledger.recordDelivered(
          _attempt(candidate: _observationClaimingMoreThanTheWords()),
        );

        expect(outcome.consumedFreeProof, isFalse);
        expect(
          outcome.rejection,
          ProductValueDeliveryRejection.semanticValidationFailed,
        );
      },
    );

    test('suppressed output does not consume free proof', () async {
      final ledger = store();

      final outcome = await ledger.recordDelivered(
        _attempt(
          candidate: _observation(),
          feedback: [
            InsightFeedbackRecord(
              insightId: 'observation-report',
              insightType: InsightFeedbackType.auditableConclusion,
              choice: InsightFeedbackChoice.hide,
              createdAt: DateTime.utc(2026, 8, 1),
              sourceRoute: 'record',
            ),
          ],
        ),
      );

      expect(outcome.consumedFreeProof, isFalse);
      expect(outcome.rejection, ProductValueDeliveryRejection.outputSuppressed);
      expect((await ledger.read()).deliveredArtifactIds, isEmpty);
    });

    test(
      'generated but unrendered output does not consume free proof',
      () async {
        final ledger = store();

        final outcome = await ledger.recordDelivered(
          _attempt(candidate: _observation(), rendered: false),
        );

        expect(outcome.consumedFreeProof, isFalse);
        expect(outcome.rejection, ProductValueDeliveryRejection.notRendered);
      },
    );

    test('failed persistence does not consume free proof', () async {
      final ledger = store();

      final outcome = await ledger.recordDelivered(
        _attempt(candidate: _observation(), artifactPersisted: false),
      );

      expect(outcome.consumedFreeProof, isFalse);
      expect(
        outcome.rejection,
        ProductValueDeliveryRejection.persistenceFailed,
      );
    });

    test('idempotent retry does not consume free proof twice', () async {
      final ledger = store();

      final first = await ledger.recordDelivered(
        _attempt(candidate: _observation()),
      );
      final retry = await ledger.recordDelivered(
        _attempt(candidate: _observation()),
      );

      expect(first.consumedFreeProof, isTrue);
      expect(retry.consumedFreeProof, isFalse);
      expect(retry.delivered, isTrue);
      expect(retry.rejection, ProductValueDeliveryRejection.alreadyDelivered);
      expect(
        (await ledger.read()).firstValidObservationDeliveredAt,
        DateTime.utc(2026, 8, 2),
      );
    });

    test('observation and comparison hold separate free slots', () async {
      final ledger = store();

      await ledger.recordDelivered(_attempt(candidate: _observation()));
      final comparison = await ledger.recordDelivered(
        _attempt(candidate: _comparison()),
      );

      final state = await ledger.read();
      expect(comparison.consumedFreeProof, isTrue);
      expect(state.firstValidObservationArtifactId, 'observation-report');
      expect(state.firstValidComparisonArtifactId, 'comparison-work-message');
      expect(state.productValue.generatedCapabilities, {
        CapabilityId.firstEvidenceObservation,
        CapabilityId.firstEarlyComparison,
      });
    });

    test(
      'delivered proof survives a restart and stays archive scoped',
      () async {
        await store().recordDelivered(_attempt(candidate: _observation()));

        final reopened = await store().read();
        final otherArchive = await store(archiveId: 'other-account').read();

        expect(reopened.firstValidObservationArtifactId, 'observation-report');
        expect(reopened.policyVersion, MonetizationPolicy.policyVersion);
        expect(otherArchive.deliveredArtifactIds, isEmpty);
        expect(
          otherArchive.hasDelivered(DeliveredValueKind.observation),
          isFalse,
        );
      },
    );

    test('delivered artifacts stay readable after Pro expiry', () async {
      final ledger = store();
      await ledger.recordDelivered(_attempt(candidate: _observation()));
      final state = await ledger.read();

      const expired = EntitlementSnapshot(
        plan: PlanKind.free,
        status: EntitlementStatus.expired,
      );
      final read = AccessPolicyEngine.decide(
        capability: CapabilityId.readExistingGeneratedOutput,
        entitlement: expired,
        productValue: state.productValue,
      );

      expect(read.allowed, isTrue);
      expect(read.kind, AccessDecisionKind.allowedReadOnly);
      expect(state.deliveredArtifactIds, contains('observation-report'));

      final coordinator = PostSaveExperienceCoordinator(
        entitlement: expired,
        deliveryLedger: state,
      );
      final entry = _entry(
        id: 'report',
        at: DateTime.utc(2026, 8, 1, 9),
        transcript: _observationTranscript,
        observation: _observation(),
      );

      final result = coordinator.build(_saved(entry, [entry]));

      expect(result.conclusion?.value.id, 'observation-report');
    });
  });

  group('free value is delivered by success, not archive position', () {
    test(
      'a later qualifying entry still delivers the first observation free',
      () {
        final barren = _entry(
          id: 'barren',
          at: DateTime.utc(2026, 7, 1),
          transcript: 'The garden tomatoes were ready and I cooked dinner.',
        );
        final qualifying = _entry(
          id: 'report',
          at: DateTime.utc(2026, 8, 1, 9),
          transcript: _observationTranscript,
          observation: _observation(),
        );

        const coordinator = PostSaveExperienceCoordinator();
        final result = coordinator.build(
          _saved(qualifying, [barren, qualifying]),
        );

        expect(result.kind, PostSaveExperienceKind.firstSave);
        expect(result.conclusion?.value.id, 'observation-report');
      },
    );

    test('a later first genuine comparison is still free', () {
      final first = _entry(
        id: 'first',
        at: DateTime.utc(2026, 7, 1),
        transcript:
            'I answered the work message immediately and felt worried about '
            'the deadline.',
      );
      final unrelated = _entry(
        id: 'unrelated',
        at: DateTime.utc(2026, 7, 2),
        transcript: 'The garden tomatoes were ready and I cooked dinner.',
      );
      final third = _entry(
        id: 'third',
        at: DateTime.utc(2026, 7, 3),
        transcript:
            'I paused before answering the work message and felt calm about '
            'the deadline.',
      );

      const coordinator = PostSaveExperienceCoordinator();
      final result = coordinator.build(
        _saved(third, [first, unrelated, third]),
      );

      expect(result.kind, PostSaveExperienceKind.secondRelatedSave);
      expect(
        result.conclusion!.value.evidence.map((item) => item.entryId).toSet(),
        {'first', 'third'},
      );
    });

    test('a spent comparison slot is not offered again', () {
      final first = _entry(
        id: 'first',
        at: DateTime.utc(2026, 7, 1),
        transcript:
            'I answered the work message immediately and felt worried about '
            'the deadline.',
      );
      final second = _entry(
        id: 'second',
        at: DateTime.utc(2026, 7, 3),
        transcript:
            'I paused before answering the work message and felt calm about '
            'the deadline.',
      );
      final coordinator = PostSaveExperienceCoordinator(
        deliveryLedger: const ProductValueDeliveryLedger.empty()
            .recordDelivered(
              kind: DeliveredValueKind.comparison,
              artifactId: 'already-delivered',
              at: DateTime.utc(2026, 7, 4),
            ),
      );

      final result = coordinator.build(_saved(second, [first, second]));

      expect(result.kind, PostSaveExperienceKind.noConclusion);
      expect(result.conclusion, isNull);
    });
  });
}

const _observationTranscript =
    'I checked the finished report again before sending it.';

ProductValueDeliveryAttempt _attempt({
  required ExplainableConclusion? candidate,
  bool generationSucceeded = true,
  bool artifactPersisted = true,
  bool rendered = true,
  Iterable<InsightFeedbackRecord> feedback = const [],
}) => ProductValueDeliveryAttempt(
  candidate: candidate,
  canonicalTranscripts: const {
    'report': _observationTranscript,
    'then': 'I answered the work message immediately.',
    'now': 'I paused before answering the work message.',
  },
  generationSucceeded: generationSucceeded,
  artifactPersisted: artifactPersisted,
  rendered: rendered,
  feedback: feedback,
);

ExplainableConclusion _observation() => ExplainableConclusion(
  id: 'observation-report',
  kind: ExplainableInsightKind.observation,
  statement: 'You described checking the finished report again.',
  confidence: 60,
  reasoning: const [
    'The saved words describe checking the finished report again.',
  ],
  uncertaintyNote: 'One saved moment cannot show whether this repeats.',
  evidence: [
    TranscriptEvidenceCitation(
      entryId: 'report',
      quote: _observationTranscript,
      startUtf16: 0,
      endUtf16: _observationTranscript.length,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: DateTime.utc(2026, 8, 1, 9),
      sourceType: EvidenceSourceType.text,
    ),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'This may be specific to this one report.',
      rationale: 'ArchiveMe has only one supporting saved moment so far.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 8, 2),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
);

ExplainableConclusion _observationWithStaleOffsets() => ExplainableConclusion(
  id: 'observation-stale',
  kind: ExplainableInsightKind.observation,
  statement: 'You described checking the finished report again.',
  confidence: 60,
  reasoning: const [
    'The saved words describe checking the finished report again.',
  ],
  uncertaintyNote: 'One saved moment cannot show whether this repeats.',
  evidence: [
    TranscriptEvidenceCitation(
      entryId: 'report',
      quote: _observationTranscript,
      startUtf16: 1,
      endUtf16: _observationTranscript.length,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: DateTime.utc(2026, 8, 1, 9),
      sourceType: EvidenceSourceType.text,
    ),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'This may be specific to this one report.',
      rationale: 'ArchiveMe has only one supporting saved moment so far.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 8, 2),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
);

ExplainableConclusion _observationClaimingMoreThanTheWords() =>
    ExplainableConclusion(
      id: 'observation-overreach',
      kind: ExplainableInsightKind.observation,
      statement: 'You described avoiding difficult family conversations.',
      confidence: 60,
      reasoning: const [
        'The saved words describe checking the finished report again.',
      ],
      uncertaintyNote: 'One saved moment cannot show whether this repeats.',
      evidence: [
        TranscriptEvidenceCitation(
          entryId: 'report',
          quote: _observationTranscript,
          startUtf16: 0,
          endUtf16: _observationTranscript.length,
          role: TranscriptEvidenceRole.supporting,
          sourceCapturedAt: DateTime.utc(2026, 8, 1, 9),
          sourceType: EvidenceSourceType.text,
        ),
      ],
      alternatives: const [
        ExplainableAlternative(
          statement: 'This may be specific to this one report.',
          rationale: 'ArchiveMe has only one supporting saved moment so far.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'test',
        generatedAt: DateTime.utc(2026, 8, 2),
        schemaVersion: ExplainableConclusion.schemaVersion,
      ),
    );

ExplainableConclusion _comparison() {
  const thenQuote = 'I answered the work message immediately.';
  const nowQuote = 'I paused before answering the work message.';
  return ExplainableConclusion(
    id: 'comparison-work-message',
    kind: ExplainableInsightKind.change,
    statement: 'Your work message response may have changed.',
    confidence: 70,
    reasoning: const ['Both saved moments mention the same work message.'],
    uncertaintyNote:
        'Two saved moments can support a comparison but not a lasting change.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'then',
        quote: thenQuote,
        startUtf16: 0,
        endUtf16: thenQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime.utc(2026, 7, 1),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.then,
      ),
      TranscriptEvidenceCitation(
        entryId: 'now',
        quote: nowQuote,
        startUtf16: 0,
        endUtf16: nowQuote.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime.utc(2026, 7, 3),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.now,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'The circumstances may explain the difference.',
        rationale: 'Later saved moments could support a different reading.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime.utc(2026, 8, 2),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
  );
}

SavedMomentResult _saved(JournalEntry entry, List<JournalEntry> entries) =>
    SavedMomentResult(
      entry: entry,
      entries: entries,
      analysisSucceeded: true,
      syncSucceeded: true,
    );

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  ExplainableConclusion? observation,
}) => JournalEntry(
  id: id,
  createdAt: at,
  transcript: transcript,
  durationSeconds: 0,
  source: SavedMomentSource.typed,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: transcript,
    concreteObservation: observation?.statement ?? '',
    repeatedSignal: '',
    explainableConclusion: observation,
  ),
);
