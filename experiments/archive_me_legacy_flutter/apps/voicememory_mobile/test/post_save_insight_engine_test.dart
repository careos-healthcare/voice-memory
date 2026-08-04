import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/post_save_insight/post_save_insight_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

FirstSessionPattern _pattern() {
  return FirstSessionPattern(
    id: 'test',
    createdAt: DateTime(2026, 6, 1),
    title: 'Taking responsibility before asking for help',
    whyNoticed: 'You mentioned pressure or responsibility.',
    watchForText: 'whether you take responsibility before asking for help',
    chips: const ['saying yes fast'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I said yes again.',
    matchReason: 'Your words pointed toward pressure in this moment.',
    confidenceScore: 0.5,
    categoryId: 'responsibility',
    category: FirstSessionPatternCategory.responsibility,
  );
}

JournalEntry _entry(String transcript, {String id = '1', DateTime? createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 1),
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  const engine = PostSaveInsightEngine();

  test('uses interpretation reads when entry provided', () {
    final bundle = engine.build(
      _pattern(),
      entry: _entry(
        'I said yes when I had no capacity, and now I feel pressure.',
      ),
    );

    expect(bundle.signals, isNotEmpty);
    expect(bundle.signals, hasLength(1));
    expect(
      bundle.signals.first.title.toLowerCase(),
      anyOf(contains('saying yes'), contains('capacity')),
    );
    expect(bundle.signals.first.evidenceUsed, isNotNull);
    expect(bundle.signals.first.readId, isNotNull);
    final conclusion = bundle.signals.first.explainableConclusion!;
    expect(conclusion.kind, ExplainableInsightKind.observation);
    expect(
      conclusion.alternativeExplanation.statement,
      contains('specific to this moment'),
    );
    expect(
      conclusion.alternativeExplanation.rationale,
      contains('only one supporting moment'),
    );
    final citation = conclusion.evidence.single;
    expect(citation.sourceCapturedAt, DateTime(2026, 6, 1));
    expect(citation.sourceType, EvidenceSourceType.text);
    expect(conclusion.nextRecordingPrompt, isNotEmpty);
    expect(
      _entry(
        'I said yes when I had no capacity, and now I feel pressure.',
      ).transcript.substring(citation.startUtf16, citation.endUtf16),
      citation.quote,
    );
  });

  test('fails closed without a canonical source entry', () {
    final bundle = engine.build(_pattern());
    expect(bundle.signals, isEmpty);
    expect(bundle.needsClearerMoment, isTrue);
  });

  test('two related moments produce one early auditable comparison', () {
    final prior = _entry(
      'I paused before answering the message because I wanted to check first.',
      id: 'prior',
      createdAt: DateTime(2026, 6, 1),
    );
    final latest = _entry(
      'Again I paused before answering the message and checked my calendar.',
      id: 'latest',
      createdAt: DateTime(2026, 6, 2),
    );
    final bundle = engine.build(
      _pattern(),
      entry: latest,
      priorEntries: [prior],
      reflectionCount: 2,
    );

    expect(bundle.impossibleInsight, isNull);
    expect(bundle.signals, hasLength(1));
    final conclusion = bundle.signals.single.explainableConclusion!;
    expect(conclusion.kind, ExplainableInsightKind.change);
    expect(
      conclusion.evidence.map((item) => item.entryId),
      orderedEquals(['prior', 'latest']),
    );
    expect(
      conclusion.evidence.map((item) => item.temporalRole),
      orderedEquals([EvidenceTemporalRole.then, EvidenceTemporalRole.now]),
    );
  });
}
