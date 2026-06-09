import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_models.dart';

void main() {
  test('parses monthly V2 with biggest surprise and strongest contradiction', () {
    final review = ArchiveMonthlyReview.fromJson({
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
  });

  test('parses milestone review', () {
    final review = ArchiveMilestoneReview.fromJson({
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
}

Map<String, dynamic> _conclusion(String id) => {
      'id': id,
      'statement': 'The archive weighed evidence from recordings.',
      'confidencePercent': 62,
      'uncertaintyNote': 'Thin evidence in one theme.',
      'evidence': [
        {'entryId': 'e1', 'role': 'support'},
      ],
    };
