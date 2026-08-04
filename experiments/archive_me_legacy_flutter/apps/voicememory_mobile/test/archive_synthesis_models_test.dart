import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_models.dart';

void main() {
  test('parses monthly V4 with five-pillar conclusions', () {
    final review = ArchiveMonthlyReview.fromJson({
      'reviewVersion': 4,
      'monthKey': '2026-05',
      'archiveHash': 'abc',
      'eligibleCount': 80,
      'generatedAt': '2026-05-01T00:00:00Z',
      'model': 'gpt-4o-mini',
      'whatChanged': [_conclusion('wc1')],
      'emergingTheories': [],
      'fadingTheories': [],
      'surprises': [],
      'biggestSurprise': _conclusion('bs1'),
      'strongestContradiction': _conclusion('sc1'),
      'evidenceFor': [_conclusion('ef1')],
      'evidenceAgainst': [],
    });
    expect(review, isNotNull);
    expect(review!.biggestSurprise?.id, 'bs1');
    expect(review.strongestContradiction?.id, 'sc1');
    expect(review.whatChanged.single.reasoning, hasLength(2));
    expect(
      review.whatChanged.single.alternativeExplanation.statement,
      contains('situational'),
    );
  });

  test('parses milestone review', () {
    final review = ArchiveMilestoneReview.fromJson({
      'reviewVersion': 4,
      'milestoneThreshold': 100,
      'eligibleCount': 100,
      'archiveHash': 'h',
      'generatedAt': '2026-05-01T00:00:00Z',
      'model': 'gpt-4o-mini',
      'headline': 'The first 100 reflections reveal…',
      'narrative': 'The archive weighed recurring work stress.',
      'primaryTheorySummary': _conclusion('p1'),
      'changeHighlights': [_conclusion('c1')],
      'uncertaintyNote': 'More recordings could shift this.',
    });
    expect(review?.milestoneThreshold, 100);
    expect(review?.headline, contains('100'));
  });

  test('fails closed when any V4 explainability pillar is missing', () {
    final missingReasoning = _conclusion('invalid')..remove('reasoning');
    final review = ArchiveMonthlyReview.fromJson({
      'reviewVersion': 4,
      'monthKey': '2026-05',
      'archiveHash': 'abc',
      'eligibleCount': 80,
      'generatedAt': '2026-05-01T00:00:00Z',
      'model': 'gpt-4o-mini',
      'whatChanged': [missingReasoning],
      'emergingTheories': [],
      'fadingTheories': [],
      'surprises': [],
      'evidenceFor': [],
      'evidenceAgainst': [],
    });

    expect(review?.whatChanged, isEmpty);
  });

  for (final version in [1, 2, 3]) {
    test('loads legacy V$version conclusions with safe fallbacks', () {
      final review = ArchiveMonthlyReview.fromJson({
        'reviewVersion': version,
        'monthKey': '2025-12',
        'archiveHash': 'legacy-$version',
        'eligibleCount': 20,
        'generatedAt': '2025-12-31T00:00:00Z',
        'model': 'legacy-model',
        'whatChanged': [
          {'id': 'legacy-insight', 'statement': 'An older cached pattern.'},
        ],
        'emergingTheories': [],
        'fadingTheories': [],
        'surprises': [],
        'evidenceFor': [],
        'evidenceAgainst': [],
      });

      final conclusion = review!.whatChanged.single;
      expect(conclusion.isLegacy, isTrue);
      expect(conclusion.confidenceKnown, isFalse);
      expect(conclusion.reasoning, ['Derived from older vault patterns.']);
      expect(conclusion.alternativeExplanation.statement, isNotEmpty);
      expect(conclusion.uncertainty, isNotEmpty);
      expect(conclusion.explainability.isLegacy, isTrue);
    });
  }
}

Map<String, dynamic> _conclusion(String id) => {
  'id': id,
  'statement': 'The archive weighed evidence from recordings.',
  'confidence': 62,
  'confidencePercent': 62,
  'reasoning': [
    'The cited words contain the observed theme.',
    'The confidence remains bounded by one source.',
  ],
  'alternativeExplanation': {
    'statement': 'The wording may be situational.',
    'reason': 'One entry does not prove a durable pattern.',
  },
  'uncertainty': 'Thin evidence in one theme.',
  'uncertaintyNote': 'Thin evidence in one theme.',
  'evidence': [
    {
      'entryId': 'e1',
      'quote': 'evidence',
      'startUtf16': 21,
      'endUtf16': 29,
      'role': 'support',
    },
  ],
  'alternatives': [
    {
      'statement': 'The wording may be situational.',
      'reason': 'One entry does not prove a durable pattern.',
    },
  ],
  'provenance': {
    'generatedBy': 'model',
    'generatedAt': '2026-05-01T00:00:00Z',
    'schemaVersion': 4,
    'promptVersion': 'archive-explainable-v2',
  },
};
