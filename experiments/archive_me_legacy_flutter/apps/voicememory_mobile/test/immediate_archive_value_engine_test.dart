import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/immediate_archive_value/immediate_archive_value_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

Reflection _reflection({List<String> themes = const []}) {
  return Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: themes,
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  );
}

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 5, 1),
    transcript: transcript,
    durationSeconds: 40,
    reflection: _reflection(themes: themes),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  test('first recording insight uses career uncertainty when evidenced', () {
    final insight = buildFirstRecordingInsight([
      _entry(
        id: '1',
        transcript:
            'I keep wondering whether I am in the right career. I feel uncertain about my next move at work.',
      ),
    ]);
    expect(insight.primaryTheme, 'Career');
    expect(insight.firstObservation, contains('career uncertainty'));
    expect(insight.firstObservation, startsWith('This moment may'));
    expect(insight.strongestQuote, isNotNull);
    expect(
      insight.strongestQuote!.split(RegExp(r'\s+')).length,
      greaterThanOrEqualTo(8),
    );
  });

  test('comparison detects shared career across two recordings', () {
    final comparison = buildSecondRecordingComparison([
      _entry(
        id: '1',
        createdAt: DateTime.utc(2026, 5, 1),
        transcript:
            'My career path feels uncertain and I am not sure what to do next at work.',
      ),
      _entry(
        id: '2',
        createdAt: DateTime.utc(2026, 5, 3),
        transcript:
            'Still thinking about career change. I am not sure if I should leave my job.',
        themes: const ['career'],
      ),
    ]);
    expect(comparison.lines.any((l) => l.contains('Career')), isTrue);
    expect(
      comparison.lines.any((l) => l.toLowerCase().contains('not sure')),
      isTrue,
    );
  });

  test('pattern requires three recordings and detects recurring theme', () {
    final pattern = buildThirdRecordingPattern([
      _entry(
        id: '1',
        transcript:
            'Career uncertainty keeps coming up when I think about my job future.',
      ),
      _entry(
        id: '2',
        createdAt: DateTime.utc(2026, 5, 2),
        transcript:
            'Another day worrying about my career and whether to switch roles.',
        themes: const ['career'],
      ),
      _entry(
        id: '3',
        createdAt: DateTime.utc(2026, 5, 4),
        transcript:
            'I talked with my manager about career growth and next steps at work.',
        themes: const ['career'],
      ),
    ]);
    expect(pattern.lines.any((l) => l.contains('all 3 recordings')), isTrue);
  });

  test('weak evidence does not invent theme-specific observation', () {
    final insight = buildFirstRecordingInsight([
      _entry(id: '1', transcript: 'ok'),
    ]);
    expect(insight.primaryTheme, isNull);
    expect(insight.firstObservation, isNull);
  });

  test('a short theme keyword is not enough for an observation', () {
    final insight = buildFirstRecordingInsight([
      _entry(id: '1', transcript: 'Work felt fine.'),
    ]);
    expect(insight.firstObservation, isNull);
    expect(insight.strongestQuote, isNull);
  });

  test('momentum at four recordings', () {
    final entries = List.generate(
      4,
      (i) => _entry(
        id: '$i',
        createdAt: DateTime.utc(2026, 5, i + 1),
        transcript:
            'Reflection number ${i + 1} about work and career uncertainty in enough detail here.',
      ),
    );
    final momentum = buildArchiveMomentum(entries);
    expect(momentum.progressLabel, '4 of 5 recordings');
    expect(momentum.confidenceLabel, isIn(['Low', 'Building']));
    expect(momentum.body, contains('one more'));
  });

  test('immediate value mode threshold', () {
    expect(isImmediateArchiveValueMode(1), isTrue);
    expect(isImmediateArchiveValueMode(4), isTrue);
    expect(isImmediateArchiveValueMode(5), isFalse);
  });
}
