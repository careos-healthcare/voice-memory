import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_trigger.dart';

void main() {
  test('requires at least 50 eligible reflections', () {
    expect(
      ArchiveSynthesisTrigger.shouldRequestSynthesis(
        eligibleCount: 49,
        monthKey: '2026-05',
        lastReviewMonthKey: null,
        celebratedMilestones: {},
        cachedArchiveHash: null,
        currentArchiveHash: 'abc',
      ),
      isFalse,
    );
  });

  test('skips when archive hash unchanged', () {
    expect(
      ArchiveSynthesisTrigger.shouldRequestSynthesis(
        eligibleCount: 100,
        monthKey: '2026-05',
        lastReviewMonthKey: '2026-04',
        celebratedMilestones: {50, 100},
        cachedArchiveHash: 'same-hash',
        currentArchiveHash: 'same-hash',
      ),
      isFalse,
    );
  });

  test('monthly review due triggers synthesis', () {
    expect(
      ArchiveSynthesisTrigger.shouldRequestSynthesis(
        eligibleCount: 80,
        monthKey: '2026-05',
        lastReviewMonthKey: '2026-04',
        celebratedMilestones: {50},
        cachedArchiveHash: 'old',
        currentArchiveHash: 'new',
      ),
      isTrue,
    );
  });

  test('milestone 100 triggers when not yet celebrated', () {
    expect(
      ArchiveSynthesisTrigger.newlyReachedMilestone(
        eligibleCount: 100,
        celebratedMilestones: {50},
      ),
      100,
    );
    expect(
      ArchiveSynthesisTrigger.shouldRequestSynthesis(
        eligibleCount: 100,
        monthKey: '2026-05',
        lastReviewMonthKey: '2026-05',
        celebratedMilestones: {50},
        cachedArchiveHash: 'a',
        currentArchiveHash: 'b',
      ),
      isTrue,
    );
  });
}
