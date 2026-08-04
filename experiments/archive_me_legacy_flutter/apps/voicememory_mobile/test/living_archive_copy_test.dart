import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/living_archive/living_archive_copy.dart';
import 'package:voicememory_mobile/features/living_archive/living_archive_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String line) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 5, 1 + id.hashCode % 20),
    transcript: '$line — enough transcript length for evidence threshold here.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: '',
      emotionalIntensity: 3,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('confidence headline uses warm reflective phrasing', () {
    expect(
      LivingArchiveCopy.confidenceChangeHeadline(61, 73),
      'ArchiveMe feels more certain about this than before.',
    );
  });

  test('mention count uses last three recordings', () {
    final entries = [
      _entry('1', 'I feel uncertain about work'),
      _entry('2', 'More uncertainty today'),
      _entry('3', 'Still uncertain and stressed'),
      _entry('4', 'uncertainty again in this reflection'),
      _entry('5', 'uncertainty keeps showing up'),
    ];
    final line = LivingArchiveCopy.mentionCountInRecentRecordings(
      themeLabel: 'uncertainty',
      entries: entries,
      keywords: const ['uncertain', 'uncertainty'],
    );
    expect(line, contains('last 3 recordings'));
    expect(line, contains('uncertainty'));
  });

  test('work to relationships wrong headline', () {
    expect(
      LivingArchiveCopy.themeDominanceWrongHeadline(
        priorThemeKey: 'work',
        currentThemeKey: 'relationship',
      ),
      contains('no longer believes work'),
    );
  });

  test('curiosity headlines avoid dashboard tone', () {
    expect(
      LivingArchiveCopy.curiosityHeadlineForPriority(
        MostImportantInsightPriority.dailyDiscovery,
      ),
      'Your archive noticed something.',
    );
  });
}
