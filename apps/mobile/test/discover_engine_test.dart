import 'package:archiveme_mobile/features/discover/discover_cache.dart';
import 'package:archiveme_mobile/features/discover/discover_engine.dart';
import 'package:archiveme_mobile/features/discover/discover_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — padding for evidence threshold in transcript body.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() => DiscoverYourselfCache.instance.invalidate());

  test('empty archive uses empty insight mode', () {
    final snapshot = const DiscoverYourselfEngine().build(entries: []);
    expect(snapshot.mode, DiscoverInsightMode.empty);
    expect(snapshot.header.totalRecordings, 0);
    expect(snapshot.belief, isNull);
  });

  test('early archive uses early mode message band', () {
    final entries = List.generate(
      3,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026, 1, i + 1),
        line: 'Reflection $i with enough detail',
      ),
    );
    final snapshot = const DiscoverYourselfEngine().build(entries: entries);
    expect(snapshot.mode, DiscoverInsightMode.early);
    expect(snapshot.showEarlyInsights, isFalse);
  });

  test('growing archive enables early insight sections', () {
    final entries = List.generate(
      8,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026, 1, i + 1),
        line: 'Growing archive reflection $i',
        themes: i.isEven ? const ['career'] : const ['family'],
      ),
    );
    final snapshot = const DiscoverYourselfEngine().build(entries: entries);
    expect(snapshot.mode, DiscoverInsightMode.growing);
    expect(snapshot.showEarlyInsights, isTrue);
    expect(snapshot.showFullSections, isFalse);
    expect(snapshot.themes, isNotEmpty);
  });

  test('cache returns same snapshot without rebuild', () {
    final entries = List.generate(
      25,
      (i) => _entry(
        id: 'e$i',
        at: DateTime(2026).add(Duration(days: i)),
        line: 'Full archive line $i',
        themes: const ['confidence'],
      ),
    );
    const engine = DiscoverYourselfEngine();
    final first = engine.build(entries: entries);
    final second = engine.build(entries: entries);
    expect(identical(first, second), isTrue);
    expect(second.mode, DiscoverInsightMode.full);
  });

  test('ask archive answers cite entry ids when possible', () {
    final entries = [
      _entry(
        id: 'a',
        at: DateTime(2026, 3),
        line: 'I feel more confident about my career direction',
        themes: const ['career', 'confidence'],
      ),
      _entry(
        id: 'b',
        at: DateTime(2026, 4),
        line: 'Career clarity is growing and I am ready to act',
        themes: const ['career'],
      ),
      ...List.generate(
        6,
        (i) => _entry(
          id: 'pad$i',
          at: DateTime(2026, 2, i + 1),
          line: 'Neutral filler with career and confidence themes',
          themes: const ['career'],
        ),
      ),
    ];

    const engine = DiscoverYourselfEngine();
    final answer = engine.answerArchiveQuestion(
      prompt: 'What am I becoming more confident about?',
      entries: entries,
    );
    expect(answer, isNotNull);
    expect(answer!.citedEntryIds, isNotEmpty);
    expect(
      answer.answerLines.join(' '),
      anyOf(contains('confident'), contains('assured')),
    );
  });
}