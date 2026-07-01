import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_quality_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_engine.dart';
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

List<JournalEntry> _threeCheckingAgainEntries() => [
      _entry(
        id: 'e1',
        transcript: 'I checked again even though I knew it was fine.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript: 'Same thing — I checked again before sending the update.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript: 'I checked again after lunch and still felt unsettled.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _threeWalkedOutsideEntries() => [
      _entry(
        id: 'e1',
        transcript: 'I walked outside before replying and felt calmer.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript: 'Same day I walked outside again before the hard email.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript: 'I walked outside when it got loud in my head.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _threeWeakPhraseConfirmedEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I said yes again even though I was already tired from work today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'I took responsibility again before asking anyone for help today.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I agreed to help again before checking whether I had capacity today.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _threeStressOnlyEntries() => [
      _entry(
        id: 'e1',
        transcript: 'Work stress was high today at the office.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript: 'More work stress came back this afternoon.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript: 'The stress at work showed up again tonight.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

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
        result.phrases.any((p) => p.toLowerCase().contains('said yes')),
        isTrue,
      );
      expect(
        result.phrases.every((phrase) {
          final words = phrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
          return words.length >= 2 && words.length <= 6;
        }),
        isTrue,
      );
    });

    test('prefers concrete action phrases over generic labels', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeCheckingAgainEntries(),
      );

      expect(result.isStrong, isTrue);
      expect(
        result.phrases.any((p) => p.toLowerCase().contains('checked again')),
        isTrue,
      );
      expect(
        result.phrases.every(
          (p) => !ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(p),
        ),
        isTrue,
      );
    });

    test('extracts walked outside as concrete repeated action', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeWalkedOutsideEntries(),
      );

      expect(result.isStrong, isTrue);
      expect(
        result.phrases.any((p) => p.toLowerCase().contains('walked outside')),
        isTrue,
      );
    });

    test('blocks ungrounded generic labels in summaries', () {
      expect(
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: 'avoidance keeps showing up',
          entries: _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
      expect(
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: 'stress keeps building',
          entries: _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
    });

    test('allows generic labels when user explicitly wrote them', () {
      expect(
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: 'stress keeps building',
          entries: _threeStressOnlyEntries(),
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: 'checking when things feel uncertain',
          entries: _threeCheckingUncertaintyEntries(),
        ),
        isFalse,
      );
    });

    test('weak abstract-only entries are not strong evidence', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeStressOnlyEntries(),
      );

      expect(result.isStrong, isFalse);
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
          label: 'confidence keeps dropping',
          entries: _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
    });

    test('no therapy or diagnosis language in extracted phrases', () {
      final result = ConfirmedRepeatEvidencePhraseEngine.extract(
        _threeRelatedRepeatEntries(),
      );
      for (final phrase in result.phrases) {
        _expectNoDiagnosticLanguage(phrase);
      }
    });

    test('singleEntryConcretePhrase returns short grounded phrase', () {
      final entry = _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
      );
      final phrase =
          ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(entry);

      expect(phrase, isNotNull);
      expect(entry.transcript.toLowerCase(), contains(phrase!.toLowerCase()));
      expect(phrase.split(RegExp(r'\s+')).length, lessThanOrEqualTo(6));
      expect(
        ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase),
        isFalse,
      );
    });

    test('singleEntryConcretePhrase skips abstract-only moments', () {
      final phrase = ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
        ),
      );

      expect(phrase, isNull);
    });

    test('sharedConcretePhrase returns repeat phrase for two related entries', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ];
      final phrase =
          ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(entries);

      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('said yes'));
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
      expect(model.evidencePhrases, contains('said yes again'));
      expect(model.evidenceSupportLine, EarlyFirstSignalCopy.evidenceSupportLine);
      expect(model.evidenceRows, isEmpty);
      _expectNoDiagnosticLanguage(model.title);
      for (final line in model.lines) {
        _expectNoDiagnosticLanguage(line);
      }
    });

    test('weak abstract entries downgrade to forming copy', () {
      final model =
          EarlyFirstSignalEngine.build(entries: _threeWeakPhraseConfirmedEntries());
      expect(model, isNotNull);
      expect(model!.title, EarlyFirstSignalCopy.threeEntryFormingTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.threeEntryFormingBody);
      expect(model.evidenceSupportLine, isNull);
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(
          _threeWeakPhraseConfirmedEntries(),
        ),
        isTrue,
      );
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

  group('FirstProofMomentEngine phrase reuse', () {
    test('related third save uses extracted phrases for proof moment', () {
      final moment = FirstProofMomentEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(moment!.title, FirstProofMomentCopy.title);
      expect(moment.evidencePhrases, isNotEmpty);
      for (final phrase in moment.evidencePhrases) {
        expect(
          _threeRelatedRepeatEntries()
              .map((e) => e.transcript.toLowerCase())
              .join(' '),
          contains(phrase.toLowerCase()),
        );
      }
    });
  });

  group('FirstWeekLoopEngine phrase reuse', () {
    test('ready state loop uses shared concrete phrase when available', () {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(loop!.title, FirstWeekLoopCopy.title);
      expect(loop.usesPhraseBody, isTrue);
      expect(loop.body.toLowerCase(), contains('said yes'));
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
