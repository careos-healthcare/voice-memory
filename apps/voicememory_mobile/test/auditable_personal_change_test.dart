import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/auditable_conclusion_trust_policy.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/auditable_personal_change_engine.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_store.dart';
import 'package:voicememory_mobile/features/insight_feedback/explainable_conclusion_feedback_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  required DateTime createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt,
  transcript: transcript,
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

ExplainableConclusion _observation({
  required String id,
  required String statement,
  required List<TranscriptEvidenceCitation> evidence,
  String theoryId = 'work_template',
  int confidence = 60,
}) => ExplainableConclusion(
  id: id,
  statement: statement,
  confidence: confidence,
  reasoning: const ['The exact work wording supports this narrow read.'],
  uncertaintyNote: 'This may be specific to these saved circumstances.',
  evidence: evidence,
  alternatives: const [
    ExplainableAlternative(
      statement: 'This may be specific to the moment.',
      rationale: 'Later saved moments may support or challenge this read.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 8),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  theoryId: theoryId,
);

TranscriptEvidenceCitation _citation(
  String entryId,
  String quote,
  DateTime capturedAt,
) => TranscriptEvidenceCitation(
  entryId: entryId,
  quote: quote,
  startUtf16: 0,
  endUtf16: quote.length,
  role: TranscriptEvidenceRole.supporting,
  sourceCapturedAt: capturedAt,
  sourceType: EvidenceSourceType.text,
);

ExplainableConclusion _change({
  required TranscriptEvidenceCitation thenEvidence,
  required TranscriptEvidenceCitation nowEvidence,
}) => ExplainableConclusion(
  id: 'change',
  statement: 'The work response may have changed.',
  confidence: 70,
  reasoning: const ['The exact work response differs across two moments.'],
  uncertaintyNote: 'Two moments do not establish a lasting change.',
  evidence: [thenEvidence, nowEvidence],
  alternatives: const [
    ExplainableAlternative(
      statement: 'The circumstances may have changed instead.',
      rationale: 'Two moments cannot separate context from lasting change.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 8),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  kind: ExplainableInsightKind.change,
);

void main() {
  group('auditable validator gates', () {
    const thenQuote = 'The work response felt urgent.';
    const nowQuote = 'The work response felt calmer.';

    TranscriptEvidenceCitation evidence({
      required String id,
      required String quote,
      required DateTime date,
      required EvidenceTemporalRole role,
      EvidenceSourceType sourceType = EvidenceSourceType.text,
    }) => TranscriptEvidenceCitation(
      entryId: id,
      quote: quote,
      startUtf16: 0,
      endUtf16: quote.length,
      role: TranscriptEvidenceRole.supporting,
      temporalRole: role,
      sourceCapturedAt: date,
      sourceType: sourceType,
    );

    test('blocks unknown source type and deleted source', () {
      final receipt = _change(
        thenEvidence: evidence(
          id: 'then',
          quote: thenQuote,
          date: DateTime.utc(2026, 7, 1),
          role: EvidenceTemporalRole.then,
          sourceType: EvidenceSourceType.unknown,
        ),
        nowEvidence: evidence(
          id: 'now',
          quote: nowQuote,
          date: DateTime.utc(2026, 7, 2),
          role: EvidenceTemporalRole.now,
        ),
      );
      final result = ExplainableConclusionValidator.validate(
        receipt,
        canonicalTranscripts: const {'now': nowQuote},
      );
      expect(
        result.blockReasons,
        contains(ExplainableConclusionBlockReason.invalidSourceType),
      );
      expect(
        result.blockReasons,
        contains(ExplainableConclusionBlockReason.missingTranscript),
      );
    });

    test('blocks identical and chronologically reversed Then and Now', () {
      final identical = _change(
        thenEvidence: evidence(
          id: 'then',
          quote: thenQuote,
          date: DateTime.utc(2026, 7, 1),
          role: EvidenceTemporalRole.then,
        ),
        nowEvidence: evidence(
          id: 'now',
          quote: thenQuote,
          date: DateTime.utc(2026, 7, 2),
          role: EvidenceTemporalRole.now,
        ),
      );
      final reversed = _change(
        thenEvidence: evidence(
          id: 'then',
          quote: thenQuote,
          date: DateTime.utc(2026, 7, 3),
          role: EvidenceTemporalRole.then,
        ),
        nowEvidence: evidence(
          id: 'now',
          quote: nowQuote,
          date: DateTime.utc(2026, 7, 2),
          role: EvidenceTemporalRole.now,
        ),
      );
      expect(
        ExplainableConclusionValidator.validate(
          identical,
          canonicalTranscripts: const {'then': thenQuote, 'now': thenQuote},
        ).blockReasons,
        contains(ExplainableConclusionBlockReason.changeEvidenceNotDistinct),
      );
      expect(
        ExplainableConclusionValidator.validate(
          reversed,
          canonicalTranscripts: const {'then': thenQuote, 'now': nowQuote},
        ).blockReasons,
        contains(
          ExplainableConclusionBlockReason.changeRequiresDistinctSources,
        ),
      );
    });
  });

  group('early auditable comparison', () {
    final then = _entry(
      id: 'then',
      transcript:
          'I answered the work message immediately and felt worried about '
          'the deadline.',
      createdAt: DateTime.utc(2026, 7, 20),
    );
    final now = _entry(
      id: 'now',
      transcript:
          'I paused before answering the work message and felt calm about '
          'the deadline.',
      createdAt: DateTime.utc(2026, 7, 31),
    );

    test(
      'two related distinct moments produce an ordered exact comparison',
      () {
        final result = AuditablePersonalChangeEngine.buildEarlyComparison(
          entries: [now, then],
        );

        expect(result, isNotNull);
        final value = result!.conclusion.value;
        expect(value.kind, ExplainableInsightKind.change);
        expect(value.evidence, hasLength(2));
        expect(
          value.evidence.map((item) => item.entryId),
          orderedEquals(['then', 'now']),
        );
        expect(
          value.evidence.map((item) => item.temporalRole),
          orderedEquals([EvidenceTemporalRole.then, EvidenceTemporalRole.now]),
        );
        expect(
          then.transcript.substring(
            value.evidence.first.startUtf16,
            value.evidence.first.endUtf16,
          ),
          value.evidence.first.quote,
        );
        expect(
          now.transcript.substring(
            value.evidence.last.startUtf16,
            value.evidence.last.endUtf16,
          ),
          value.evidence.last.quote,
        );
      },
    );

    test('unrelated moments and identical wording produce no comparison', () {
      final unrelated = _entry(
        id: 'relationship',
        transcript:
            'I enjoyed a quiet dinner with my sister and talked about music.',
        createdAt: DateTime.utc(2026, 7, 31),
      );
      final identical = _entry(
        id: 'same',
        transcript: then.transcript,
        createdAt: DateTime.utc(2026, 7, 31),
      );

      expect(
        AuditablePersonalChangeEngine.buildEarlyComparison(
          entries: [then, unrelated],
        ),
        isNull,
      );
      expect(
        AuditablePersonalChangeEngine.buildEarlyComparison(
          entries: [then, identical],
        ),
        isNull,
      );
    });
  });

  group('production trust ranking', () {
    const quote = 'Work pressure felt urgent today.';
    final citation = _citation('work-1', quote, DateTime.utc(2026, 7, 1));
    const transcripts = {'work-1': quote};

    test('removes zero confidence, generic and identity claims', () {
      for (final candidate in [
        _observation(
          id: 'zero',
          statement: 'Work pressure felt urgent.',
          evidence: [citation],
          confidence: 0,
        ),
        _observation(
          id: 'generic',
          statement: 'This may mean something about work.',
          evidence: [citation],
        ),
        _observation(
          id: 'trait',
          statement: 'You are a naturally anxious work person.',
          evidence: [citation],
        ),
      ]) {
        expect(
          AuditableConclusionTrustPolicy.rankBest(
            candidates: [candidate],
            canonicalTranscripts: transcripts,
          ),
          isNull,
        );
      }
    });

    test('does not rank a relationship conclusion from work evidence', () {
      final unrelated = _observation(
        id: 'relationship',
        statement: 'Your relationship felt distant.',
        evidence: [citation],
        theoryId: 'relationship_template',
      );
      expect(
        AuditableConclusionTrustPolicy.rankBest(
          candidates: [unrelated],
          canonicalTranscripts: transcripts,
        ),
        isNull,
      );
    });

    test('accurate feedback changes ranking but never confidence', () {
      final first = _observation(
        id: 'first',
        statement: 'Work pressure felt urgent.',
        evidence: [citation],
      );
      final second = _observation(
        id: 'second',
        statement: 'Work pressure felt urgent today.',
        evidence: [citation],
        theoryId: 'second_template',
      );
      final feedback = InsightFeedbackRecord(
        insightId: 'first',
        insightType: InsightFeedbackType.auditableConclusion,
        choice: InsightFeedbackChoice.accurate,
        createdAt: DateTime.utc(2026, 7, 2),
        sourceRoute: 'test',
        templateId: 'work_template',
        evidenceEntryIds: const ['work-1'],
      );

      final ranked = AuditableConclusionTrustPolicy.rankBest(
        candidates: [second, first],
        canonicalTranscripts: transcripts,
        feedback: [feedback],
      );
      expect(ranked?.conclusion.value.id, 'first');
      expect(ranked?.conclusion.value.confidence, first.confidence);
    });

    test(
      'wrong angle suppresses old evidence and permits corrected new evidence',
      () {
        final original = _observation(
          id: 'first',
          statement: 'Work pressure felt urgent.',
          evidence: [citation],
        );
        final feedback = InsightFeedbackRecord(
          insightId: 'first',
          insightType: InsightFeedbackType.auditableConclusion,
          choice: InsightFeedbackChoice.wrongAngle,
          createdAt: DateTime.utc(2026, 7, 2),
          sourceRoute: 'test',
          templateId: 'work_template',
          evidenceEntryIds: const ['work-1'],
          correctionNote: 'The deadline, not the workload, was the issue.',
        );
        expect(
          AuditableConclusionTrustPolicy.rankBest(
            candidates: [original],
            canonicalTranscripts: transcripts,
            feedback: [feedback],
          ),
          isNull,
        );

        const newQuote = 'Work pressure felt calmer after the deadline moved.';
        final updated = _observation(
          id: 'updated',
          statement: 'Work pressure felt calmer.',
          evidence: [
            citation,
            _citation('work-2', newQuote, DateTime.utc(2026, 7, 3)),
          ],
        );
        final ranked = AuditableConclusionTrustPolicy.rankBest(
          candidates: [updated],
          canonicalTranscripts: {...transcripts, 'work-2': newQuote},
          feedback: [feedback],
        );
        expect(ranked, isNotNull);
        expect(ranked!.wasCorrectedByUser, isTrue);
        expect(ranked.conclusion.value.correctionNote, feedback.correctionNote);
        expect(ranked.conclusion.value.confidence, updated.confidence);
      },
    );

    test(
      'wrong angle suppresses a semantic-equivalent rewording on old evidence',
      () {
        final feedback = InsightFeedbackRecord(
          insightId: 'original',
          insightType: InsightFeedbackType.auditableConclusion,
          choice: InsightFeedbackChoice.wrongAngle,
          createdAt: DateTime.utc(2026, 7, 2),
          sourceRoute: 'test',
          templateId: 'work_template',
          evidenceEntryIds: const ['work-1'],
          correctionNote: 'The deadline was the issue.',
        );
        final equivalent = _observation(
          id: 'reworded',
          statement: 'Urgency showed up around work pressure.',
          evidence: [citation],
        );

        expect(
          AuditableConclusionTrustPolicy.rankBest(
            candidates: [equivalent],
            canonicalTranscripts: transcripts,
            feedback: [feedback],
          ),
          isNull,
        );
      },
    );

    test('too generic suppresses the same template without new evidence', () {
      final original = _observation(
        id: 'generic-old',
        statement: 'Work pressure felt urgent.',
        evidence: [citation],
      );
      final feedback = InsightFeedbackRecord(
        insightId: 'generic-old',
        insightType: InsightFeedbackType.auditableConclusion,
        choice: InsightFeedbackChoice.tooGeneric,
        createdAt: DateTime.utc(2026, 7, 2),
        sourceRoute: 'test',
        templateId: 'work_template',
        evidenceEntryIds: const ['work-1'],
      );

      expect(
        AuditableConclusionTrustPolicy.rankBest(
          candidates: [original],
          canonicalTranscripts: transcripts,
          feedback: [feedback],
        ),
        isNull,
      );
    });

    test('private correction round-trips without altering evidence text', () {
      final record = InsightFeedbackRecord(
        insightId: 'first',
        insightType: InsightFeedbackType.auditableConclusion,
        choice: InsightFeedbackChoice.wrongAngle,
        createdAt: DateTime.utc(2026, 7, 2),
        sourceRoute: 'test',
        templateId: 'work_template',
        evidenceEntryIds: const ['work-1'],
        correctionNote: 'The deadline was the issue.',
      );
      final restored = InsightFeedbackRecord.fromJson(record.toJson());

      expect(restored.correctionNote, record.correctionNote);
      expect(restored.evidenceEntryIds, ['work-1']);
      expect(citation.quote, quote);
    });

    test(
      'correction survives store recreation and analytics excludes text',
      () async {
        await AppServices.resetForTest(
          journalPath:
              '${DateTime.now().microsecondsSinceEpoch}_auditable_journal.json',
          prefsPath:
              '${DateTime.now().microsecondsSinceEpoch}_auditable_prefs.json',
          skipRevenueCat: true,
        );
        ProductAnalytics.resetForTest();
        final conclusion = AuditableConclusionTrustPolicy.rankBest(
          candidates: [
            _observation(
              id: 'persisted',
              statement: 'Work pressure felt urgent.',
              evidence: [citation],
            ),
          ],
          canonicalTranscripts: transcripts,
        )!.conclusion;
        const correction = 'The deadline, not workload, was the issue.';

        await ExplainableConclusionFeedbackCoordinator.submit(
          conclusion: conclusion,
          choice: InsightFeedbackChoice.wrongAngle,
          correctionNote: correction,
          origin: 'test',
        );
        final reloaded = await InsightFeedbackStore(
          AppServices.instance.prefs,
        ).loadAll();

        expect(reloaded.single.correctionNote, correction);
        expect(citation.quote, quote);
        final analyticsPayload = ProductAnalytics.eventsForTest
            .map((event) => event.parameters.toString())
            .join(' ');
        expect(analyticsPayload, isNot(contains(correction)));
        expect(analyticsPayload, isNot(contains(quote)));
        expect(analyticsPayload, isNot(contains('Work pressure felt urgent')));
      },
    );
  });

  group('app-authored placeholders are never treated as the user speaking', () {
    // '[draft] Audio saved without a transcript' is 40 characters, so it clears
    // the minimum-length filter and reads like a sentence. Only an explicit
    // placeholder check keeps it out of evidence.
    const placeholder = '[draft] Audio saved without a transcript';

    test('a placeholder cannot be quoted as a comparison source', () {
      final base = DateTime.utc(2026, 7, 1);
      final ranked = AuditablePersonalChangeEngine.buildEarlyComparison(
        entries: [
          _entry(id: 'audio-only', transcript: placeholder, createdAt: base),
          _entry(
            id: 'spoken',
            transcript:
                'I checked the report again after I had already finished it.',
            createdAt: base.add(const Duration(days: 2)),
          ),
        ],
      );

      // One real moment and one placeholder is one moment, not a pair.
      expect(
        ranked,
        isNull,
        reason:
            'A comparison was built against app-authored text. Anything shown '
            'here would quote words the user never said.',
      );
    });

    test('the placeholder predicate matches only app-authored text', () {
      final base = DateTime.utc(2026, 7, 1);
      expect(
        AuditablePersonalChangeEngine.holdsGeneratedPlaceholder(
          _entry(id: 'a', transcript: placeholder, createdAt: base),
        ),
        isTrue,
      );
      expect(
        AuditablePersonalChangeEngine.holdsGeneratedPlaceholder(
          _entry(
            id: 'b',
            transcript: 'I drafted the email and then deleted it again.',
            createdAt: base,
          ),
        ),
        isFalse,
        reason:
            'A user genuinely writing about a draft must still be quotable.',
      );
    });
  });
}
