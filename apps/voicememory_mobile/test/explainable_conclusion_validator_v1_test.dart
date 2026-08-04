import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';

void main() {
  test('rejects relationship claims supported only by work evidence', () {
    const transcript = 'My work response felt cautious after the deadline.';
    final result = ExplainableConclusionValidator.validate(
      _conclusion(
        statement: 'Your relationship response may be cautious.',
        transcript: transcript,
      ),
      canonicalTranscripts: const {'entry-1': transcript},
    );

    expect(
      result.blockReasons,
      contains(ExplainableConclusionBlockReason.topicDomainMismatch),
    );
  });

  test('rejects zero confidence and identity language', () {
    const transcript = 'I checked the completed task one more time.';
    final zero = ExplainableConclusionValidator.validate(
      _conclusion(
        statement: 'You described checking the completed task again.',
        transcript: transcript,
        confidence: 0,
      ),
      canonicalTranscripts: const {'entry-1': transcript},
    );
    final identity = ExplainableConclusionValidator.validate(
      _conclusion(
        statement: 'You are a person who always checks the completed task.',
        transcript: transcript,
      ),
      canonicalTranscripts: const {'entry-1': transcript},
    );

    expect(
      zero.blockReasons,
      contains(ExplainableConclusionBlockReason.nonPositiveConfidence),
    );
    expect(
      identity.blockReasons,
      contains(ExplainableConclusionBlockReason.identityOrDiagnosisLanguage),
    );
  });
}

ExplainableConclusion _conclusion({
  required String statement,
  required String transcript,
  int confidence = 60,
}) => ExplainableConclusion(
  id: 'conclusion-1',
  statement: statement,
  confidence: confidence,
  reasoning: const ['The exact saved wording supports this cautious read.'],
  uncertaintyNote: 'This may be specific to this saved moment.',
  evidence: [
    TranscriptEvidenceCitation(
      entryId: 'entry-1',
      quote: transcript,
      startUtf16: 0,
      endUtf16: transcript.length,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: DateTime.utc(2026, 8),
      sourceType: EvidenceSourceType.text,
      confidenceScore: 0.65,
    ),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'This may be specific to this moment.',
      rationale: 'One saved moment cannot establish a repeated pattern.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 8, 2),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  kind: ExplainableInsightKind.observation,
);
