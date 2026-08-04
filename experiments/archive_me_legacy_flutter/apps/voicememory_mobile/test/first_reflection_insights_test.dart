import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_reflection/first_reflection_insights.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

Reflection _reflection({
  String observation = '',
  String pattern = '',
  List<String> themes = const [],
}) {
  return Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: themes,
    exactLanguagePattern: pattern,
    concreteObservation: observation,
    repeatedSignal: '',
  );
}

JournalEntry _entry({required String transcript, Reflection? reflection}) {
  return JournalEntry(
    id: '1',
    createdAt: DateTime.utc(2026, 5, 1),
    transcript: transcript,
    durationSeconds: 30,
    reflection:
        reflection ??
        _reflection(
          pattern: 'I am not sure this career path is right for me anymore.',
          themes: const ['career'],
        ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  test('exact phrase suppresses generic career summary', () {
    final insights = buildFirstReflectionInsights([
      _entry(
        transcript:
            'I keep thinking about my job and I am uncertain whether I should change careers soon.',
      ),
    ]);
    expect(
      insights.noticedLines.any(
        (line) => line.contains('“I am not sure this career path'),
      ),
      isTrue,
    );
    expect(
      insights.noticedLines.any((line) => line.startsWith('You mentioned')),
      isFalse,
    );
    expect(insights.themeNames, contains('Career'));
  });

  test('concrete observation and quote lead the first insight', () {
    final insights = buildFirstReflectionInsights([
      _entry(
        transcript:
            'When my manager asks late, I say yes before checking tomorrow.',
        reflection: _reflection(
          pattern: 'say yes before checking tomorrow',
          observation:
              'When your manager asks late, you say yes before checking tomorrow.',
          themes: const ['career'],
        ),
      ),
    ]);
    expect(insights.noticedLines.single, contains('say yes before checking'));
    expect(
      insights.noticedLines.single,
      contains('When your manager asks late'),
    );
  });

  test('thin input does not manufacture a theme insight', () {
    final insights = buildFirstReflectionInsights([
      _entry(transcript: 'too short', reflection: _reflection()),
    ]);
    expect(insights.noticedLines, isEmpty);
  });

  test('first reflection mode threshold', () {
    expect(isFirstReflectionMode(0), isFalse);
    expect(isFirstReflectionMode(1), isTrue);
    expect(isFirstReflectionMode(4), isTrue);
    expect(isFirstReflectionMode(5), isFalse);
  });
}
