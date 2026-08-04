import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_models.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainability_history_store.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_mappers.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  const transcript = 'A😀B';
  final transcripts = {'entry-1': transcript};

  ExplainableConclusion conclusion({
    int confidence = 60,
    int start = 1,
    int end = 3,
    String quote = '😀',
  }) => ExplainableConclusion(
    id: 'conclusion-1',
    statement: 'A conclusion',
    confidence: confidence,
    reasoning: const [
      'The cited phrase directly supports this bounded conclusion.',
    ],
    uncertaintyNote: 'This may change with more recordings.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-1',
        quote: quote,
        startUtf16: start,
        endUtf16: end,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime.utc(2025, 12, 31),
        sourceType: EvidenceSourceType.text,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'Another explanation',
        rationale: 'The evidence can also be read this way.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime.utc(2026),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
  );

  test('accepts explicit UTF-16 offsets around a non-BMP character', () {
    final result = ExplainableConclusionValidator.validate(
      conclusion(),
      canonicalTranscripts: transcripts,
    );

    expect(result.isValid, isTrue);
    expect(result.evidenceConfidenceCap, 70);
  });

  test('fails closed for quote mismatch and split surrogate boundary', () {
    final mismatch = ExplainableConclusionValidator.validate(
      conclusion(quote: 'x'),
      canonicalTranscripts: transcripts,
    );
    final split = ExplainableConclusionValidator.validate(
      conclusion(start: 2),
      canonicalTranscripts: transcripts,
    );

    expect(
      mismatch.blockReasons,
      contains(ExplainableConclusionBlockReason.quoteMismatch),
    );
    expect(
      split.blockReasons,
      contains(ExplainableConclusionBlockReason.splitSurrogatePair),
    );
  });

  test('fails closed when a source capture date is missing', () {
    final source = conclusion();
    final missingDate = ExplainableConclusion(
      id: source.id,
      statement: source.statement,
      confidence: source.confidence,
      reasoning: source.reasoning,
      uncertaintyNote: source.uncertaintyNote,
      evidence: [
        TranscriptEvidenceCitation(
          entryId: 'entry-1',
          quote: '😀',
          startUtf16: 1,
          endUtf16: 3,
          role: TranscriptEvidenceRole.supporting,
          sourceType: EvidenceSourceType.text,
        ),
      ],
      alternatives: source.alternatives,
      provenance: source.provenance,
    );

    expect(
      ExplainableConclusionValidator.validate(
        missingDate,
        canonicalTranscripts: transcripts,
      ).blockReasons,
      contains(ExplainableConclusionBlockReason.missingSourceCapturedAt),
    );
  });

  test('blocks confidence above evidence-calibrated cap', () {
    final result = ExplainableConclusionValidator.validate(
      conclusion(confidence: 71),
      canonicalTranscripts: transcripts,
    );

    expect(
      result.blockReasons,
      contains(ExplainableConclusionBlockReason.confidenceExceedsEvidenceCap),
    );
  });

  test('confidence caps exactly match backend citation-count semantics', () {
    TranscriptEvidenceCitation citation(
      String id,
      TranscriptEvidenceRole role,
    ) => TranscriptEvidenceCitation(
      entryId: id,
      quote: 'x',
      startUtf16: 0,
      endUtf16: 1,
      role: role,
      sourceCapturedAt: DateTime.utc(2025, 12, 31),
      sourceType: EvidenceSourceType.text,
    );

    expect(ExplainableConclusionValidator.evidenceConfidenceCap(const []), 0);
    expect(
      ExplainableConclusionValidator.evidenceConfidenceCap([
        citation('same', TranscriptEvidenceRole.supporting),
        citation('same', TranscriptEvidenceRole.supporting),
      ]),
      70,
    );
    expect(
      ExplainableConclusionValidator.evidenceConfidenceCap([
        citation('s1', TranscriptEvidenceRole.supporting),
        citation('s2', TranscriptEvidenceRole.supporting),
        citation('s3', TranscriptEvidenceRole.supporting),
        citation('c1', TranscriptEvidenceRole.contradicting),
        citation('c2', TranscriptEvidenceRole.contradicting),
        citation('c3', TranscriptEvidenceRole.contradicting),
        citation('c4', TranscriptEvidenceRole.contradicting),
      ]),
      50,
    );
  });

  test(
    'requires support, meaningful uncertainty, and a distinct alternative',
    () {
      final source = conclusion();
      final invalid = ExplainableConclusion(
        id: source.id,
        statement: source.statement,
        confidence: 0,
        reasoning: const ['The related citation does not provide support.'],
        uncertaintyNote: 'unknown',
        evidence: [
          TranscriptEvidenceCitation(
            entryId: 'entry-1',
            quote: '😀',
            startUtf16: 1,
            endUtf16: 3,
            role: TranscriptEvidenceRole.related,
            sourceCapturedAt: DateTime.utc(2025, 12, 31),
            sourceType: EvidenceSourceType.text,
          ),
        ],
        alternatives: const [
          ExplainableAlternative(
            statement: ' A CONCLUSION ',
            rationale: 'Same conclusion with different casing.',
          ),
        ],
        provenance: source.provenance,
      );

      final result = ExplainableConclusionValidator.validate(
        invalid,
        canonicalTranscripts: transcripts,
      );
      expect(
        result.blockReasons,
        contains(ExplainableConclusionBlockReason.meaninglessUncertaintyNote),
      );
      expect(
        result.blockReasons,
        contains(ExplainableConclusionBlockReason.missingSupportingEvidence),
      );
      expect(
        result.blockReasons,
        contains(ExplainableConclusionBlockReason.duplicateAlternative),
      );
    },
  );

  test('render gate exposes only valid conclusions', () {
    expect(
      ExplainableConclusionRenderGate.visible(
        conclusion(),
        canonicalTranscripts: transcripts,
      ),
      isNotNull,
    );
    expect(
      ExplainableConclusionRenderGate.visible(
        conclusion(quote: 'wrong'),
        canonicalTranscripts: transcripts,
      ),
      isNull,
    );
  });

  test('maps strict backend role, alternative, and provenance names', () {
    final source = ArchiveSynthesisConclusion.fromJson({
      'id': 'backend-1',
      'statement': 'A backend conclusion',
      'confidence': 70,
      'confidencePercent': 70,
      'reasoning': ['The exact cited phrase supports this narrow conclusion.'],
      'alternativeExplanation': {
        'statement': 'A different explanation',
        'reason': 'The same words could support another interpretation.',
      },
      'uncertainty': 'More recordings could change this conclusion.',
      'uncertaintyNote': 'More recordings could change this conclusion.',
      'evidence': [
        {
          'entryId': 'entry-1',
          'quote': '😀',
          'startUtf16': 1,
          'endUtf16': 3,
          'role': 'support',
          'sourceCapturedAt': '2025-12-31T00:00:00Z',
          'sourceType': 'text',
        },
      ],
      'alternatives': [
        {
          'statement': 'A different explanation',
          'reason': 'The same words could support another interpretation.',
        },
      ],
      'provenance': {
        'generatedBy': 'model',
        'generatedAt': '2026-01-01T00:00:00Z',
        'model': 'test-model',
        'schemaVersion': 4,
        'promptVersion': 'archive-explainable-v2',
      },
    })!;

    expect(
      ExplainableConclusionMappers.fromArchiveSynthesis(
        source: source,
        canonicalTranscripts: transcripts,
      ).isValid,
      isTrue,
    );
  });

  test('Reflection round-trips exact backend conclusion field names', () {
    final reflection = Reflection.fromJson({
      'mood': 'steady',
      'emotionalIntensity': 3,
      'recurringThemes': ['work'],
      'exactLanguagePattern': '😀',
      'concreteObservation': 'A backend conclusion',
      'repeatedSignal': 'Nothing repeated clearly in this entry.',
      'explainableConclusion': {
        'id': 'backend-reflection-1',
        'statement': 'A backend conclusion',
        'confidence': 70,
        'confidencePercent': 70,
        'reasoning': [
          'The exact cited phrase supports this narrow conclusion.',
        ],
        'alternativeExplanation': {
          'statement': 'A different explanation',
          'reason': 'The same words permit another narrow reading.',
        },
        'uncertainty': 'More recordings could change this conclusion.',
        'uncertaintyNote': 'More recordings could change this conclusion.',
        'evidence': [
          {
            'sourceEntryId': 'entry-1',
            'exactQuote': '😀',
            'audioTimestampMs': 1200,
            'confidenceScore': .98,
            'entryId': 'entry-1',
            'quote': '😀',
            'startUtf16': 1,
            'endUtf16': 3,
            'role': 'support',
            'sourceCapturedAt': '2025-12-31T00:00:00Z',
            'sourceType': 'text',
          },
        ],
        'alternatives': [
          {
            'statement': 'A different explanation',
            'reason': 'The same words permit another narrow reading.',
          },
        ],
        'provenance': {
          'generatedBy': 'model',
          'generatedAt': '2026-01-01T00:00:00Z',
          'model': 'test-model',
          'schemaVersion': 4,
          'promptVersion': 'analyze-explainable-v2',
        },
      },
    });

    final encoded =
        reflection.toJson()['explainableConclusion'] as Map<String, dynamic>;
    expect(reflection.explainableConclusion?.confidencePercent, 70);
    expect(encoded['confidencePercent'], 70);
    expect(encoded['confidence'], 70);
    expect(encoded['reasoning'], isNotEmpty);
    expect((encoded['evidence'] as List).first['role'], 'support');
    expect((encoded['evidence'] as List).first['sourceEntryId'], 'entry-1');
    expect((encoded['evidence'] as List).first['exactQuote'], '😀');
    expect((encoded['evidence'] as List).first['audioTimestampMs'], 1200);
    expect((encoded['alternatives'] as List).first['reason'], isNotEmpty);
    expect(
      (encoded['provenance'] as Map<String, dynamic>)['generatedBy'],
      'model',
    );
  });

  test('legacy journal conclusion receives safe explainability fallbacks', () {
    final conclusion = ExplainableConclusion.fromJson({
      'id': 'legacy-journal-1',
      'statement': 'A cached V2 observation.',
      'confidencePercent': 58,
      'provenance': {
        'generatedBy': 'model',
        'generatedAt': '2024-01-01T00:00:00Z',
      },
    });

    expect(conclusion, isNotNull);
    expect(conclusion!.isLegacy, isTrue);
    expect(conclusion.reasoning, ['Derived from older vault patterns.']);
    expect(conclusion.alternativeExplanation.statement, isNotEmpty);
    expect(conclusion.uncertainty, isNotEmpty);
    expect(
      ExplainableConclusionRenderGate.visible(
        conclusion,
        canonicalTranscripts: const {},
      ),
      isNull,
    );
  });

  test('requires exact punctuation at the stored span', () {
    const source = 'I said “not today”.';
    final receipt = ExplainableConclusion(
      id: 'normalized',
      statement: 'You set a boundary in this moment.',
      confidence: 60,
      reasoning: const ['The cited words describe a direct boundary.'],
      uncertaintyNote: 'One moment does not establish a repeated pattern.',
      evidence: [
        TranscriptEvidenceCitation(
          entryId: 'normalized-entry',
          quote: '"not today"',
          startUtf16: 7,
          endUtf16: 18,
          role: TranscriptEvidenceRole.supporting,
          sourceCapturedAt: DateTime.utc(2025, 12, 31),
          sourceType: EvidenceSourceType.text,
        ),
      ],
      alternatives: const [
        ExplainableAlternative(
          statement: 'This may have been situational.',
          rationale: 'The context may explain the response by itself.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'test',
        generatedAt: DateTime.utc(2026),
        schemaVersion: ExplainableConclusion.schemaVersion,
      ),
    );
    expect(
      ExplainableConclusionValidator.validate(
        receipt,
        canonicalTranscripts: const {'normalized-entry': source},
      ).blockReasons,
      contains(ExplainableConclusionBlockReason.quoteMismatch),
    );
  });

  test('change receipts require distinct, ordered Then and Now sources', () {
    final generatedAt = DateTime.utc(2026, 3);
    ExplainableConclusion change({required String nowEntryId}) =>
        ExplainableConclusion(
          id: 'change-1',
          statement: 'Your response may be becoming less urgent.',
          confidence: 80,
          reasoning: const [
            'The earlier and recent moments describe different responses.',
          ],
          uncertaintyNote:
              'Two moments can suggest change but do not prove a trend.',
          evidence: [
            TranscriptEvidenceCitation(
              entryId: 'then',
              quote: 'I answered immediately',
              startUtf16: 0,
              endUtf16: 22,
              role: TranscriptEvidenceRole.supporting,
              temporalRole: EvidenceTemporalRole.then,
              sourceCapturedAt: DateTime.utc(2026, 1),
              sourceType: EvidenceSourceType.text,
            ),
            TranscriptEvidenceCitation(
              entryId: nowEntryId,
              quote: 'I waited before answering',
              startUtf16: 0,
              endUtf16: 25,
              role: TranscriptEvidenceRole.supporting,
              temporalRole: EvidenceTemporalRole.now,
              sourceCapturedAt: DateTime.utc(2026, 2),
              sourceType: EvidenceSourceType.text,
            ),
          ],
          alternatives: const [
            ExplainableAlternative(
              statement: 'The situations may have been different.',
              rationale: 'Context could explain the different response.',
            ),
          ],
          provenance: ExplainableConclusionProvenance(
            source: 'test',
            generatedAt: generatedAt,
            schemaVersion: ExplainableConclusion.schemaVersion,
          ),
          kind: ExplainableInsightKind.change,
        );

    const transcripts = {
      'then': 'I answered immediately',
      'now': 'I waited before answering',
    };
    expect(
      ExplainableConclusionValidator.validate(
        change(nowEntryId: 'now'),
        canonicalTranscripts: transcripts,
      ).isValid,
      isTrue,
    );
    expect(
      ExplainableConclusionValidator.validate(
        change(nowEntryId: 'then'),
        canonicalTranscripts: transcripts,
      ).blockReasons,
      contains(ExplainableConclusionBlockReason.changeRequiresDistinctSources),
    );
  });

  test('multi-entry patterns need distinct real sources', () {
    const sourceA = 'I checked the message twice.';
    const sourceB = 'I checked the door twice.';
    ExplainableConclusion pattern(List<TranscriptEvidenceCitation> evidence) =>
        ExplainableConclusion(
          id: 'pattern-1',
          statement: 'Across these moments, repeated checking appeared.',
          confidence: 80,
          reasoning: const [
            'Two different moments contain direct checking language.',
          ],
          uncertaintyNote:
              'Two moments may not represent a stable long-term pattern.',
          evidence: evidence,
          alternatives: const [
            ExplainableAlternative(
              statement: 'Both moments may have been situational.',
              rationale: 'Their immediate contexts may explain the checking.',
            ),
          ],
          provenance: ExplainableConclusionProvenance(
            source: 'test',
            generatedAt: DateTime.utc(2026, 3),
            schemaVersion: ExplainableConclusion.schemaVersion,
          ),
          kind: ExplainableInsightKind.pattern,
        );
    final first = TranscriptEvidenceCitation(
      entryId: 'a',
      quote: 'checked',
      startUtf16: 2,
      endUtf16: 9,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: DateTime.utc(2026, 1),
      sourceType: EvidenceSourceType.text,
    );
    final second = TranscriptEvidenceCitation(
      entryId: 'b',
      quote: 'checked',
      startUtf16: 2,
      endUtf16: 9,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: DateTime.utc(2026, 2),
      sourceType: EvidenceSourceType.text,
    );
    final transcripts = {'a': sourceA, 'b': sourceB};

    expect(
      ExplainableConclusionValidator.validate(
        pattern([first, second]),
        canonicalTranscripts: transcripts,
      ).isValid,
      isTrue,
    );
    expect(
      ExplainableConclusionValidator.validate(
        pattern([first]),
        canonicalTranscripts: transcripts,
      ).blockReasons,
      contains(ExplainableConclusionBlockReason.insufficientPatternSources),
    );
  });

  test('duplicate citations and malformed confidence fail closed', () {
    final source = conclusion();
    final duplicate = ExplainableConclusion(
      id: source.id,
      statement: source.statement,
      confidence: source.confidence,
      reasoning: source.reasoning,
      uncertaintyNote: source.uncertaintyNote,
      evidence: [source.evidence.single, source.evidence.single],
      alternatives: source.alternatives,
      provenance: source.provenance,
    );
    final badConfidence = TranscriptEvidenceCitation(
      entryId: 'entry-1',
      quote: '😀',
      startUtf16: 1,
      endUtf16: 3,
      role: TranscriptEvidenceRole.supporting,
      confidenceScore: 1.2,
      sourceCapturedAt: DateTime.utc(2025, 12, 31),
      sourceType: EvidenceSourceType.text,
    );
    final invalidConfidence = ExplainableConclusion(
      id: source.id,
      statement: source.statement,
      confidence: source.confidence,
      reasoning: source.reasoning,
      uncertaintyNote: source.uncertaintyNote,
      evidence: [badConfidence],
      alternatives: source.alternatives,
      provenance: source.provenance,
    );

    expect(
      ExplainableConclusionValidator.validate(
        duplicate,
        canonicalTranscripts: transcripts,
      ).blockReasons,
      contains(ExplainableConclusionBlockReason.duplicateEvidence),
    );
    expect(
      ExplainableConclusionValidator.validate(
        invalidConfidence,
        canonicalTranscripts: transcripts,
      ).blockReasons,
      contains(ExplainableConclusionBlockReason.invalidEvidenceConfidence),
    );
  });

  test('unknown insight kinds never parse into the presentation pipeline', () {
    final json = conclusion().toJson()..['kind'] = 'diagnosis';
    expect(ExplainableConclusion.fromJson(json), isNull);
  });

  test(
    'persistence rebinds current-entry and fails closed on stale offsets',
    () {
      Reflection cloud(String quote, int end) => Reflection.fromJson({
        'mood': 'steady',
        'emotionalIntensity': 3,
        'recurringThemes': ['work'],
        'exactLanguagePattern': 'unverified flat quote',
        'concreteObservation': 'unverified flat observation',
        'repeatedSignal': 'unverified flat repeat',
        'explainableConclusion': {
          'id': 'cloud-1',
          'statement': 'A supported statement',
          'confidence': 70,
          'confidencePercent': 70,
          'reasoning': [
            'The exact persisted transcript slice supports this statement.',
          ],
          'alternativeExplanation': {
            'statement': 'Another explanation',
            'reason': 'The words could support a different narrow reading.',
          },
          'uncertainty': 'More recordings could change this conclusion.',
          'uncertaintyNote': 'More recordings could change this conclusion.',
          'evidence': [
            {
              'entryId': 'current-entry',
              'quote': quote,
              'startUtf16': 0,
              'endUtf16': end,
              'role': 'support',
              'sourceCapturedAt': '2025-12-31T00:00:00Z',
              'sourceType': 'text',
            },
          ],
          'alternatives': [
            {
              'statement': 'Another explanation',
              'reason': 'The words could support a different narrow reading.',
            },
          ],
          'provenance': {
            'generatedBy': 'model',
            'generatedAt': '2026-01-01T00:00:00Z',
            'schemaVersion': 4,
            'promptVersion': 'analyze-explainable-v2',
          },
        },
      });

      final valid = cloud('Saved transcript.', 17).validatedForPersistence(
        transcript: 'Saved transcript.',
        entryId: 'actual-entry-id',
      );
      expect(
        valid.explainableConclusion?.evidence.single.entryId,
        'actual-entry-id',
      );
      expect(
        valid.concreteObservation,
        'Your words include “Saved transcript.”.',
      );

      final stale = cloud('Original transcript.', 20).validatedForPersistence(
        transcript: 'Transformed transcript.',
        entryId: 'actual-entry-id',
      );
      expect(stale.concreteObservation, isNot(contains('unverified')));
      expect(
        stale.explainableConclusion?.provenance.generatedBy,
        'deterministic',
      );
    },
  );

  test('history is encrypted at rest and versions stable ids', () async {
    final directory = await Directory.systemTemp.createTemp(
      'explainability_history_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/history.enc');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    final store = ExplainabilityHistoryStore(
      file: file,
      keyStore: keyStore,
      maxEntries: 3,
    );
    addTearDown(store.dispose);
    final gated = ExplainableConclusionRenderGate.visible(
      conclusion(),
      canonicalTranscripts: transcripts,
    )!;

    await store.append(gated);
    await store.append(gated);
    final history = await store.byConclusionId('conclusion-1');

    expect(history.map((item) => item.conclusion.historyVersion), [2, 1]);
    expect(await file.readAsString(), isNot(contains('A conclusion')));
    expect(await file.readAsString(), isNot(contains('😀')));
    final exported = await store.exportPrivacySafe();
    expect(exported.toString(), isNot(contains('A conclusion')));
  });

  test('history idempotently ignores the same returned version', () async {
    final directory = await Directory.systemTemp.createTemp(
      'explainability_history_once_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = ExplainabilityHistoryStore(
      file: File('${directory.path}/history.enc'),
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    addTearDown(store.dispose);
    final gated = ExplainableConclusionRenderGate.visible(
      conclusion(),
      canonicalTranscripts: transcripts,
    )!;

    final first = await store.appendIfAbsent(gated);
    final cachedRead = await store.appendIfAbsent(gated);

    expect(
      cachedRead.conclusion.historyVersion,
      first.conclusion.historyVersion,
    );
    expect(await store.byConclusionId('conclusion-1'), hasLength(1));
  });
}
