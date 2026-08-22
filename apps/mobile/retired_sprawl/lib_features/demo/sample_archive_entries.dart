import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Deterministic in-memory sample moments — work focus and decision-making.
abstract final class SampleArchiveEntries {
  SampleArchiveEntries._();

  static const _momentOne =
      'I felt pulled between two priorities at work today and noticed I kept switching tasks.';
  static const _momentTwo =
      'I made more progress when I wrote down one decision before opening messages.';
  static const _momentThree =
      'At home, I noticed the same pattern: I delayed a small decision until it felt bigger.';
  static const _momentFour =
      'I felt calmer when I chose the next step instead of trying to solve the whole week.';
  static const _momentFive =
      'The pattern seems to be about unclear decisions, not lack of motivation.';

  static const _reflection = Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work', 'decisions'],
    exactLanguagePattern: 'unclear decisions',
    concreteObservation:
        'A moment about choosing the next step at work or home.',
    repeatedSignal: 'decision-making',
  );

  /// Five neutral sample moments spread across two weeks — never written to disk.
  static List<JournalEntry> build({DateTime? now}) {
    final base = now ?? DateTime(2026, 6, 15, 12);
    JournalEntry entry({
      required String suffix,
      required int daysAgo,
      required String transcript,
      required String contextTag,
    }) {
      return JournalEntry(
        id: '${SampleArchiveMode.entryIdPrefix}$suffix',
        createdAt: base.subtract(Duration(days: daysAgo)),
        transcript: transcript,
        durationSeconds: 22,
        reflection: _reflection,
        captureContextTag: contextTag,
      );
    }

    return [
      entry(
        suffix: 'm1',
        daysAgo: 12,
        transcript: _momentOne,
        contextTag: CaptureContextTagIds.work,
      ),
      entry(
        suffix: 'm2',
        daysAgo: 9,
        transcript: _momentTwo,
        contextTag: CaptureContextTagIds.work,
      ),
      entry(
        suffix: 'm3',
        daysAgo: 6,
        transcript: _momentThree,
        contextTag: CaptureContextTagIds.home,
      ),
      entry(
        suffix: 'm4',
        daysAgo: 3,
        transcript: _momentFour,
        contextTag: CaptureContextTagIds.home,
      ),
      entry(
        suffix: 'm5',
        daysAgo: 0,
        transcript: _momentFive,
        contextTag: CaptureContextTagIds.decision,
      ),
    ];
  }
}