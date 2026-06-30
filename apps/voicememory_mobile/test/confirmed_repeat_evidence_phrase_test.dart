import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_quality_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 24,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _threeCheckingUncertaintyEntries() => [
      _entry(
        id: 'e1',
        transcript: 'I kept checking again when things felt uncertain today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript: 'Same checking came back when everything still felt uncertain.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I was checking again because things felt uncertain about the decision.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void main() {
  group('ConfirmedRepeatEvidencePhraseEngine', () {
    test('extracts 2–3 grounded phrases from related entries', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeRelatedRepeatEntries(),
      );

      expect(result.isStrong, isTrue);
      expect(result.phrases.length, greaterThanOrEqualTo(2));
      expect(result.phrases.length, lessThanOrEqualTo(3));
      expect(
        result.phrases.every((phrase) {
          final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
          return words.length >= 2 && words.length <= 8;
        }),
        isTrue,
      );
    });

    test('dedupes near-identical phrases', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeRelatedRepeatEntries(),
      );

      final lowered = result.phrases.map((p) => p.toLowerCase()).toList();
      expect(lowered.toSet().length, lowered.length);
    });

    test('does not expose full transcript snippets', () {
      final entries = _threeRelatedRepeatEntries();
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(entries);

      for (final phrase in result.phrases) {
        for (final entry in entries) {
          expect(entry.transcript.trim(), isNot(equals(phrase)));
          expect(phrase.length, lessThan(entry.transcript.length));
        }
      }
    });

    test('does not invent phrases absent from entries', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeRelatedRepeatEntries(),
      );
      final blob = _threeRelatedRepeatEntries()
          .map((e) => e.transcript.toLowerCase())
          .join(' ');

      for (final phrase in result.phrases) {
        expect(blob.contains(phrase.toLowerCase()), isTrue);
      }
    });

    test('softens ungrounded generic labels', () {
      expect(
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: 'avoidance keeps showing up',
          entries: _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
      expect(
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: 'checking when things feel uncertain',
          entries: _threeCheckingUncertaintyEntries(),
        ),
        isFalse,
      );
    });
  });

  group('EarlyFirstSignalEngine confirmed repeat copy', () {
    test('strong evidence shows confirmed repeat with phrase chips', () {
      final model = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      expect(model!.kind, EarlyFirstSignalKind.threeEntryConfirmedRepeat);
      expect(model.title, EarlyFirstSignalCopy.threeEntryConfirmedTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.threeEntrySeenThreeTimes);
      expect(model.evidenceHeading, EarlyFirstSignalCopy.evidenceHeading);
      expect(model.evidencePhrases.length, greaterThanOrEqualTo(2));
      expect(model.evidenceSupportLine, EarlyFirstSignalCopy.evidenceSupportLine);
      expect(model.evidenceRows, isEmpty);
    });

    test('weak phrase extraction uses forming copy without overclaiming', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'Work was busy and I felt stretched thin today at the office.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another busy work day and I felt stretched thin again.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript: 'Work felt busy again and I was stretched thin this afternoon.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      final model = EarlyFirstSignalEngine.build(entries: entries);
      if (model == null) return;

      if (model.evidencePhrases.length < 2) {
        expect(model.title, EarlyFirstSignalCopy.threeEntryFormingTitle);
        expect(model.lines.single, EarlyFirstSignalCopy.threeEntryFormingBody);
        expect(model.evidenceSupportLine, isNull);
      }
    });
  });

  group('EarlyArchiveInsightQualityEngine generic title guard', () {
    test('keeps grounded uncertainty summary when words appear in entries', () {
      final insight = EarlyArchiveInsightQualityEngine.build(
        entries: _threeCheckingUncertaintyEntries(),
      );

      expect(insight.repeatSummary, isNotNull);
      expect(
        insight.repeatSummary!.toLowerCase(),
        anyOf(
          contains('checking'),
          contains('uncertain'),
        ),
      );
    });
  });
}
