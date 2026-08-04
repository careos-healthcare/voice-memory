import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_engine.dart';
import 'package:voicememory_mobile/features/archive_search/archive_search_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';

KeyMoment _moment(
  String id,
  DateTime date, {
  String title = 'Moment',
  String text = 'a moment',
  String? resultHint,
  String? patternTitle,
  List<String> tags = const [],
  String? nextCheck,
}) => KeyMoment(
  id: id,
  date: date,
  title: title,
  originalText: text,
  shortSummary: text,
  resultHint: resultHint,
  patternTitle: patternTitle,
  tags: tags,
  nextCheck: nextCheck,
);

void main() {
  const engine = ArchiveSearchEngine();
  final now = DateTime(2026, 6, 6, 9);

  test('lastSeen returns showed-up moments newest first', () {
    final moments = [
      _moment('a', DateTime(2026, 6, 1), resultHint: 'showed_up_again'),
      _moment('b', DateTime(2026, 6, 4), resultHint: 'same'),
      _moment('c', DateTime(2026, 6, 5), resultHint: 'lighter'),
    ];
    final results = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.lastSeen),
      moments,
      now: now,
    );
    expect(results.map((r) => r.momentId), ['b', 'a']);
  });

  test('helpedBefore uses helped tag or lighter result', () {
    final moments = [
      _moment(
        'a',
        DateTime(2026, 6, 1),
        text: 'I paused',
        tags: const ['helped'],
      ),
      _moment('b', DateTime(2026, 6, 2), resultHint: 'lighter'),
      _moment('c', DateTime(2026, 6, 3), resultHint: 'heavier'),
    ];
    final results = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.helpedBefore),
      moments,
      now: now,
    );
    expect(results.map((r) => r.momentId), ['b', 'a']);
  });

  test('momentsAbout filters by tag', () {
    final moments = [
      _moment('a', DateTime(2026, 6, 1), tags: const ['work']),
      _moment('b', DateTime(2026, 6, 2), tags: const ['family']),
    ];
    final results = engine.search(
      const ArchiveSearchQuery(
        intent: ArchiveSearchIntent.momentsAbout,
        normalizedTerm: 'work',
      ),
      moments,
      now: now,
    );
    expect(results.single.momentId, 'a');
  });

  test('felt lighter and felt heavier filter by result hint', () {
    final moments = [
      _moment('a', DateTime(2026, 6, 1), resultHint: 'lighter'),
      _moment('b', DateTime(2026, 6, 2), resultHint: 'heavier'),
    ];
    final lighter = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.feltLighter),
      moments,
      now: now,
    );
    expect(lighter.single.momentId, 'a');

    final heavier = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.feltHeavier),
      moments,
      now: now,
    );
    expect(heavier.single.momentId, 'b');
  });

  test('changed filters changed hints', () {
    final moments = [
      _moment('a', DateTime(2026, 6, 5), resultHint: 'changed'),
      _moment('b', DateTime(2026, 6, 4), resultHint: 'not_today'),
      _moment('c', DateTime(2026, 6, 3), resultHint: 'same'),
    ];
    final results = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.changed),
      moments,
      now: now,
    );
    expect(results.map((r) => r.momentId), ['a', 'b']);
  });

  test('this week filters to the last seven days', () {
    final moments = [
      _moment('recent', DateTime(2026, 6, 5)),
      _moment('old', DateTime(2026, 5, 20)),
    ];
    final results = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.thisWeek),
      moments,
      now: now,
    );
    expect(results.single.momentId, 'recent');
  });

  test('free text searches original text and tags', () {
    final moments = [
      _moment(
        'a',
        DateTime(2026, 6, 1),
        text: 'The worry came back when things got quiet.',
      ),
      _moment(
        'b',
        DateTime(2026, 6, 2),
        text: 'A calm morning.',
        tags: const ['work'],
      ),
    ];
    final byText = engine.search(
      ArchiveSearchQuery.fromText('worry'),
      moments,
      now: now,
    );
    expect(byText.single.momentId, 'a');

    final byTag = engine.search(
      ArchiveSearchQuery.fromText('work'),
      moments,
      now: now,
    );
    expect(byTag.single.momentId, 'b');
  });

  test('empty matches return no invented results', () {
    final results = engine.search(
      const ArchiveSearchQuery(intent: ArchiveSearchIntent.feltLighter),
      const [],
      now: now,
    );
    expect(results, isEmpty);
  });
}
