import 'package:archiveme_mobile/features/archive_evidence/archive_repeat_phrase_sanitizer.dart';
import 'package:archiveme_mobile/features/record/early_specific_insight_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

const _engine = EarlySpecificInsightEngine();

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
  transcript: transcript,
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  group('ArchiveRepeatPhraseSanitizer', () {
    test('does not output wanted to say no and to say no but', () {
      final summary = ArchiveRepeatPhraseSanitizer.buildRepeatSummary(
        texts: [
          'I wanted to say no but agreed to help anyway today.',
          'Again I wanted to say no but said yes when I was tired.',
        ],
        sharedPhrases: const ['wanted to say no', 'to say no but'],
      );

      expect(summary, isNot(contains('wanted to say no and to say no but')));
      expect(summary, isNot(contains('Both moments mention')));
      expect(summary, contains('point to'));
      expect(summary, contains('wanted to step back'));
    });

    test('does not output phrases ending in but', () {
      expect(
        ArchiveRepeatPhraseSanitizer.sanitize('to say no but'),
        'to say no',
      );
      expect(
        ArchiveRepeatPhraseSanitizer.endsWithConnector('wanted to say no but'),
        isTrue,
      );

      final summary = ArchiveRepeatPhraseSanitizer.buildRepeatSummary(
        texts: const ['wanted to say no but agreed', 'to say no but said yes'],
        sharedPhrases: const ['to say no but'],
        lowerConfidence: true,
      );
      expect(summary.toLowerCase(), isNot(RegExp(r'\bbut\.$')));
    });

    test('pressure saying-yes examples produce natural repeat copy', () {
      final summary = ArchiveRepeatPhraseSanitizer.buildRepeatSummary(
        texts: [
          'I had no capacity but I said yes again to the extra meeting today.',
          'Same thing — said yes when I had no capacity for one more thing.',
        ],
        sharedPhrases: const ['said yes', 'no capacity'],
      );

      expect(
        summary,
        'Both moments point to pressure around saying yes when you had no capacity.',
      );
    });

    test('buildEvidenceLine keeps exact snippets separate', () {
      expect(
        ArchiveRepeatPhraseSanitizer.buildEvidenceLine(const [
          'wanted to say no',
        ]),
        'Your words: "wanted to say no".',
      );
      expect(
        ArchiveRepeatPhraseSanitizer.buildEvidenceLine(const [
          'said yes',
          'no capacity',
        ]),
        'Your words: "said yes" and "no capacity".',
      );
    });

    test('dedupeNearIdentical keeps cleaner longer phrase', () {
      expect(
        ArchiveRepeatPhraseSanitizer.dedupeNearIdentical(const [
          'wanted to say no',
          'to say no but',
        ]),
        ['wanted to say no'],
      );
    });
  });

  group('EarlySpecificInsightEngine repeat copy', () {
    test('wanted to say no entries avoid awkward joined fragments', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript: 'I wanted to say no but agreed to help anyway today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript: 'Again I wanted to say no but said yes when I was tired.',
        ),
      ]);

      expect(insight.shouldShow, isTrue);
      expect(insight.oneLinePattern, isNot(contains('and to say no but')));
      expect(insight.oneLinePattern, contains('point to'));
      expect(insight.evidenceLine, startsWith('Your words:'));
      expect(insight.evidenceLine, isNot(contains(' and to ')));
    });
  });
}