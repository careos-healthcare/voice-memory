import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_value/archive_value_progress.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: ['work'],
  exactLanguagePattern: 'pattern',
  concreteObservation: 'obs',
  repeatedSignal: 'signal',
);

JournalEntry _entry(int i) => JournalEntry(
  id: 'e$i',
  createdAt: DateTime.utc(2026, 1, i),
  transcript: 'Reflection text number $i about work stress',
  durationSeconds: 10,
  reflection: _reflection(),
  syncStatus: SyncStatus.localOnly,
);

void main() {
  test('stage ladder maps reflection counts', () {
    expect(
      ArchiveValueProgress.stageForCount(1),
      ArchiveValueStage.oneDataPoint,
    );
    expect(
      ArchiveValueProgress.stageForCount(2),
      ArchiveValueStage.possibleRepeat,
    );
    expect(
      ArchiveValueProgress.stageForCount(5),
      ArchiveValueStage.patternReviewUnlocked,
    );
  });

  test('value copy includes One data point', () {
    final snap = ArchiveValueProgress.build([_entry(1)]);
    expect(snap.valueCopy, contains('One data point'));
    expect(snap.ctaLabel, 'Record another moment');
  });

  test('at 5 unlocks pattern review CTA', () {
    final entries = List.generate(5, _entry);
    final snap = ArchiveValueProgress.build(entries);
    expect(snap.readyForPatternReview, isTrue);
    expect(snap.ctaLabel, 'Open pattern review');
    expect(snap.ctaRoute, '/self-discovery?tab=blind-spots');
  });
}
