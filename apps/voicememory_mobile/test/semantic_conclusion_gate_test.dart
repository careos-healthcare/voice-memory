import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/auditable_conclusion_trust_policy.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/conclusion_confidence_model.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/semantic_conclusion_gate.dart';
import 'package:voicememory_mobile/features/insight_feedback/insight_feedback_models.dart';

/// Part 2 fixtures: a real quote is never enough. Each case proves the gate
/// decides whether the conclusion actually follows from the cited words.
void main() {
  group('domain separation', () {
    test('work evidence cannot support a relationship conclusion', () {
      final assessment = _assessChange(
        before: 'I answered the work message about the deadline.',
        after: 'I paused before answering the work message about the deadline.',
        statement: 'The relationship with your partner may have changed.',
      );

      expect(assessment.isEntailed, isFalse);
      expect(
        assessment.rejections,
        contains(SemanticConclusionRejection.unsupportedClaimLanguage),
      );
    });

    test('relationship evidence cannot support a work conclusion', () {
      final assessment = _assessChange(
        before: 'I snapped at my partner during dinner and felt guilty.',
        after: 'I listened to my partner during dinner and felt calm.',
        statement: 'The work deadline may have changed.',
      );

      expect(assessment.isEntailed, isFalse);
      expect(
        assessment.rejections,
        contains(SemanticConclusionRejection.unsupportedClaimLanguage),
      );
    });
  });

  group('change requires a moved dimension', () {
    test('different wording alone is not a change', () {
      final assessment = _assessChange(
        before: 'I checked the report before the work review.',
        after: 'I checked the report prior to the work review.',
        statement: 'The work review may have changed.',
      );

      expect(assessment.isEntailed, isFalse);
      expect(
        assessment.rejections,
        contains(SemanticConclusionRejection.changeWithoutMovedDimension),
      );
    });

    test('negation alone is not sufficient for a change', () {
      final assessment = _assessChange(
        before: 'I checked the report before the work review.',
        after: 'I did not check the report before the work review.',
        statement: 'The work review may have changed.',
      );

      expect(assessment.isEntailed, isFalse);
      expect(
        assessment.rejections,
        contains(SemanticConclusionRejection.changeWithoutMovedDimension),
      );
    });

    test('a genuine action shift is detected', () {
      final assessment = _assessChange(
        before:
            'I answered the work message immediately and felt worried about '
            'the deadline.',
        after:
            'I paused before answering the work message and felt calm about '
            'the deadline.',
        statement:
            'What you did with the work message changed between these saved '
            'moments.',
      );

      expect(assessment.rejections, isEmpty);
      expect(assessment.isEntailed, isTrue);
      expect(
        assessment.dimensions.changed.map((movement) => movement.dimension),
        contains(ChangeDimension.action),
      );
    });
  });

  group('direction claims', () {
    test('intensity weakening is rejected without intensity evidence', () {
      final assessment = _assessChange(
        before: 'I felt worried about the work deadline.',
        after: 'I paused and felt worried about the work deadline.',
        statement: 'How strongly you felt it looks less across these moments.',
      );

      expect(assessment.isEntailed, isFalse);
      expect(
        assessment.rejections,
        contains(SemanticConclusionRejection.unsupportedDirectionClaim),
      );
    });

    test('intensity weakening is accepted with intensity evidence', () {
      final assessment = _assessChange(
        before: 'I felt very worried about the work deadline.',
        after: 'I felt less worried about the work deadline.',
        statement: 'How strongly you felt it looks less across these moments.',
      );

      expect(assessment.rejections, isEmpty);
      final intensity = assessment.dimensions.changed.singleWhere(
        (movement) => movement.dimension == ChangeDimension.emotionalIntensity,
      );
      expect(intensity.direction, DimensionDirection.decreased);
    });
  });

  test('conflicting evidence yields no showable confidence', () {
    final assessment = _assessChange(
      before: 'I felt very worried and I was unsure about the work deadline.',
      after: 'I felt less worried and I was certain about the work deadline.',
      statement:
          'What you did with the work deadline changed between these moments.',
    );

    expect(assessment.dimensions.isConflicting, isTrue);
    expect(
      assessment.rejections,
      contains(SemanticConclusionRejection.conflictingDimensionEvidence),
    );
    expect(assessment.signals.value, 0);
  });

  test('generic framing is suppressed', () {
    final assessment = _assessChange(
      before: 'I answered the work message about the deadline.',
      after: 'I paused before answering the work message about the deadline.',
      statement: 'This may be a pattern in these saved moments.',
    );

    expect(assessment.isEntailed, isFalse);
    expect(
      assessment.rejections,
      contains(SemanticConclusionRejection.genericFraming),
    );
  });

  test('single-source change and same-entry Then/Now are rejected', () {
    const transcript = 'I answered the work message about the deadline.';
    final conclusion = _conclusion(
      id: 'change-single',
      kind: ExplainableInsightKind.change,
      statement: 'The work message changed between these saved moments.',
      quotes: const {'only': transcript},
      capturedAt: {'only': DateTime.utc(2026, 1, 1)},
    );

    final assessment = SemanticConclusionGate.assess(
      conclusion: conclusion,
      canonicalTranscripts: const {'only': transcript},
    );

    expect(
      assessment.rejections,
      contains(SemanticConclusionRejection.singleSourcePatternOrChange),
    );
  });

  test('a deleted source invalidates the conclusion', () {
    final assessment = _assessChange(
      before:
          'I answered the work message immediately and felt worried about '
          'the deadline.',
      after:
          'I paused before answering the work message and felt calm about '
          'the deadline.',
      statement:
          'What you did with the work message changed between these saved '
          'moments.',
      deletedEntryIds: const {'then'},
    );

    expect(
      assessment.rejections,
      contains(SemanticConclusionRejection.deletedSource),
    );
  });

  test('generated text cited as user evidence is rejected', () {
    final assessment = _assessChange(
      before:
          'I answered the work message immediately and felt worried about '
          'the deadline.',
      after:
          'I paused before answering the work message and felt calm about '
          'the deadline.',
      statement:
          'What you did with the work message changed between these saved '
          'moments.',
      generatedTextEntryIds: const {'now'},
    );

    expect(
      assessment.rejections,
      contains(SemanticConclusionRejection.generatedTextCitedAsEvidence),
    );
  });

  test('confidence is derived from signals, never assigned', () {
    final weak = ConclusionConfidenceModel.forComparison(
      dimensions: const ChangeDimensions.empty(),
      quotes: const ['it was just a thing'],
      distinctSourceCount: 1,
      citationsValid: true,
      chronologyOrdered: false,
      threadAligned: false,
    );
    final strong = ConclusionConfidenceModel.forComparison(
      dimensions: ChangeDimensionReader.compare(
        before: 'I answered the work message immediately and felt worried.',
        after: 'I paused before answering the work message and felt calm.',
      ),
      quotes: const [
        'I answered the work message immediately and felt worried.',
        'I paused before answering the work message and felt calm.',
      ],
      distinctSourceCount: 2,
      citationsValid: true,
      chronologyOrdered: true,
      threadAligned: true,
    );

    expect(weak.value, lessThan(strong.value));
    expect(strong.band, EvidenceConfidenceBand.repeatedAcrossMoments);
    expect(
      ConclusionConfidenceModel.forComparison(
        dimensions: const ChangeDimensions.empty(),
        quotes: const ['anything'],
        distinctSourceCount: 1,
        citationsValid: false,
        chronologyOrdered: true,
        threadAligned: true,
      ).value,
      0,
    );
  });

  test('user feedback changes ranking but not evidential confidence', () {
    const transcript = 'I checked the finished report again before sending it.';
    const transcripts = {'entry': transcript};
    final first = _conclusion(
      id: 'obs-a',
      kind: ExplainableInsightKind.observation,
      statement: 'You described checking the report.',
      quotes: const {'entry': transcript},
      capturedAt: {'entry': DateTime.utc(2026, 1, 1)},
    );
    final second = _conclusion(
      id: 'obs-b',
      kind: ExplainableInsightKind.observation,
      statement: 'You described sending the finished report.',
      quotes: const {'entry': transcript},
      capturedAt: {'entry': DateTime.utc(2026, 1, 1)},
    );

    final untouched = AuditableConclusionTrustPolicy.rankBest(
      candidates: [first, second],
      canonicalTranscripts: transcripts,
    );
    expect(untouched?.conclusion.value.id, 'obs-a');

    final reordered = AuditableConclusionTrustPolicy.rankBest(
      candidates: [first, second],
      canonicalTranscripts: transcripts,
      feedback: [
        InsightFeedbackRecord(
          insightId: 'obs-b',
          insightType: InsightFeedbackType.auditableConclusion,
          choice: InsightFeedbackChoice.accurate,
          createdAt: DateTime.utc(2026, 1, 2),
          sourceRoute: 'test',
          evidenceEntryIds: const ['entry'],
        ),
      ],
    );
    expect(reordered?.conclusion.value.id, 'obs-b');
    expect(reordered?.conclusion.value.confidence, second.confidence);
  });
}

SemanticConclusionAssessment _assessChange({
  required String before,
  required String after,
  required String statement,
  Set<String> deletedEntryIds = const {},
  Set<String> generatedTextEntryIds = const {},
}) {
  final conclusion = _conclusion(
    id: 'change-candidate',
    kind: ExplainableInsightKind.change,
    statement: statement,
    quotes: {'then': before, 'now': after},
    capturedAt: {
      'then': DateTime.utc(2026, 1, 1),
      'now': DateTime.utc(2026, 1, 2),
    },
  );
  return SemanticConclusionGate.assess(
    conclusion: conclusion,
    canonicalTranscripts: {'then': before, 'now': after},
    deletedEntryIds: deletedEntryIds,
    generatedTextEntryIds: generatedTextEntryIds,
  );
}

ExplainableConclusion _conclusion({
  required String id,
  required ExplainableInsightKind kind,
  required String statement,
  required Map<String, String> quotes,
  required Map<String, DateTime> capturedAt,
}) {
  return ExplainableConclusion(
    id: id,
    kind: kind,
    statement: statement,
    confidence: 60,
    reasoning: const ['Derived from the saved words below.'],
    uncertaintyNote: 'Two moments cannot establish a lasting change.',
    evidence: [
      for (final entry in quotes.entries)
        TranscriptEvidenceCitation(
          entryId: entry.key,
          quote: entry.value,
          startUtf16: 0,
          endUtf16: entry.value.length,
          role: TranscriptEvidenceRole.supporting,
          sourceCapturedAt: capturedAt[entry.key],
          sourceType: EvidenceSourceType.voice,
        ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'The wording may simply differ.',
        rationale: 'Two saved moments cannot rule this out.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime.utc(2026, 1, 3),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
  );
}
