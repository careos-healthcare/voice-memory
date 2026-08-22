import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/daily_question/adaptive_daily_question_copy.dart';
import 'package:archiveme_mobile/features/daily_question/adaptive_daily_question_engine.dart';
import 'package:archiveme_mobile/features/daily_question/adaptive_daily_question_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

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
    localAudioPath: '/tmp/$id.m4a',
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

List<JournalEntry> _fourRelatedRepeatEntries() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourRelatedRepeatWithHelpfulAction() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript: 'I paused before replying this time and it felt a bit softer.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

RepeatReturnCheckRecord _choiceRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: 4,
  createdAt: DateTime(2026, 6, 13, 12),
);

void _expectNoAdviceLanguage(String copy) {
  for (final phrase in ProofSurfaceAdviceGuard.bannedAdvicePhrases) {
    expect(
      copy.toLowerCase(),
      isNot(contains(phrase)),
      reason: 'must not contain "$phrase"',
    );
  }
  expect(copy.toLowerCase(), isNot(contains('therapy')));
  expect(copy.toLowerCase(), isNot(contains('diagnosis')));
  expect(copy.toLowerCase(), isNot(contains('you always')));
}

void main() {
  group('AdaptiveDailyQuestionEngine', () {
    test('0 entries shows first real moment question', () {
      final result = AdaptiveDailyQuestionEngine.build(entries: const []);

      expect(result.kind, AdaptiveDailyQuestionKind.noEntries);
      expect(result.questionText, AdaptiveDailyQuestionCopy.noEntriesQuestion);
      expect(result.helperText, AdaptiveDailyQuestionCopy.noEntriesHelper);
    });

    test('1 entry shows similar-again question', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.oneEntry);
      expect(result.questionText, AdaptiveDailyQuestionCopy.oneEntryQuestion);
      expect(result.helperText, AdaptiveDailyQuestionCopy.oneEntryHelper);
    });

    test('2 entries no clear match shows similar/different question', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
          _entry(
            id: '2',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.twoNoClearMatch);
      expect(
        result.questionText,
        AdaptiveDailyQuestionCopy.twoNoClearMatchQuestion,
      );
      expect(
        result.helperText,
        AdaptiveDailyQuestionCopy.twoNoClearMatchHelper,
      );
    });

    test('2 related entries ask for one more related moment', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            id: '2',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.twoRelated);
      expect(result.questionText, AdaptiveDailyQuestionCopy.twoRelatedQuestion);
      expect(result.helperText, AdaptiveDailyQuestionCopy.twoRelatedHelper);
    });

    test('first proof uses grounded phrase when available', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      expect(result.kind, AdaptiveDailyQuestionKind.confirmedRepeat);
      expect(result.usesPhrase, isTrue);
      expect(result.questionText, contains('said yes again'));
      expect(
        result.questionText,
        AdaptiveDailyQuestionCopy.confirmedRepeatQuestion('said yes again'),
      );
      expect(
        result.helperText,
        AdaptiveDailyQuestionCopy.confirmedRepeatHelper,
      );
    });

    test('first proof fallback works without phrase', () {
      expect(
        AdaptiveDailyQuestionCopy.confirmedRepeatQuestionFallback,
        'Did this repeat come back today?',
      );

      final withPhrase = AdaptiveDailyQuestionEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(withPhrase.kind, AdaptiveDailyQuestionKind.confirmedRepeat);
      expect(withPhrase.usesPhrase, isTrue);

      final withoutFoundation = AdaptiveDailyQuestionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
          _entry(
            id: '2',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
          _entry(
            id: '3',
            transcript: 'A calm evening walk before bed tonight.',
          ),
        ],
      );
      expect(
        withoutFoundation.questionText,
        isNot(AdaptiveDailyQuestionCopy.confirmedRepeatQuestionFallback),
      );
    });

    test('softer return question renders', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.returnSofter);
      expect(
        result.questionText,
        AdaptiveDailyQuestionCopy.returnSofterQuestion,
      );
      expect(result.helperText, AdaptiveDailyQuestionCopy.returnSofterHelper);
    });

    test('stronger return question renders', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.stronger,
          ),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.returnStronger);
      expect(
        result.questionText,
        AdaptiveDailyQuestionCopy.returnStrongerQuestion,
      );
    });

    test('same return question renders', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.returnSame);
      expect(result.questionText, AdaptiveDailyQuestionCopy.returnSameQuestion);
    });

    test('pattern changed question takes priority over normal repeat', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript:
              'I said yes again even though I had no capacity for one more ask today.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      final result = AdaptiveDailyQuestionEngine.build(
        entries: entries,
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.changed),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.patternChanged);
      expect(
        result.questionText,
        AdaptiveDailyQuestionCopy.patternChangedQuestion,
      );
      expect(result.helperText, AdaptiveDailyQuestionCopy.patternChangedHelper);
    });

    test('helpful action question takes highest priority', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );

      expect(result.kind, AdaptiveDailyQuestionKind.helpfulActionAppeared);
      expect(result.usesPhrase, isTrue);
      expect(result.questionText, contains('paused before replying'));
      expect(result.helperText, AdaptiveDailyQuestionCopy.helpfulActionHelper);
    });

    test('helpful action fallback when milestone captured without phrase', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
        helpfulActionCapturedMilestone: true,
      );

      expect(result.kind, AdaptiveDailyQuestionKind.helpfulActionAppeared);
      expect(
        result.questionText,
        AdaptiveDailyQuestionCopy.helpfulActionQuestionFallback,
      );
    });

    test('phrase max 6 words in confirmed repeat question', () {
      final result = AdaptiveDailyQuestionEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      if (result.usesPhrase) {
        final match = RegExp('“([^”]+)”').firstMatch(result.questionText);
        expect(match, isNotNull);
        final phrase = match!.group(1)!;
        expect(phrase.split(RegExp(r'\s+')).length, lessThanOrEqualTo(6));
      }
    });

    test('no transcript dumps in question or helper', () {
      final entries = _fourRelatedRepeatWithHelpfulAction();
      final privateText = entries.last.transcript;
      final result = AdaptiveDailyQuestionEngine.build(entries: entries);

      expect(result.questionText, isNot(contains(privateText)));
      expect(result.helperText, isNot(contains(privateText)));
      expect(result.questionText.length, lessThan(120));
    });

    test('copy avoids advice coaching therapy and personality language', () {
      AdaptiveDailyQuestionCopy.allVisibleStrings.forEach(_expectNoAdviceLanguage);

      final sample = AdaptiveDailyQuestionEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
      );
      _expectNoAdviceLanguage(sample.questionText);
      _expectNoAdviceLanguage(sample.helperText);
    });
  });
}