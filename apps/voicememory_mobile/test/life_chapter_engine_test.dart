import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/life_chapters/life_chapter_engine.dart';
import 'package:voicememory_mobile/features/life_chapters/life_chapter_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — additional transcript padding for evidence threshold.',
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

List<JournalEntry> _burnoutThenConfidenceArc() {
  return [
    ...List.generate(
      3,
      (i) => _entry(
        id: 'burn$i',
        at: DateTime(2025, 2, i + 1),
        line: 'I feel burnout and exhausted at work every day',
        themes: const ['health', 'career'],
      ),
    ),
    ...List.generate(
      3,
      (i) => _entry(
        id: 'gap$i',
        at: DateTime(2025, 5, i + 1),
        line: 'Neutral filler reflection with enough transcript text here.',
      ),
    ),
    ...List.generate(
      3,
      (i) => _entry(
        id: 'conf$i',
        at: DateTime(2026, 3, i + 10),
        line: 'I am more confident and trust my judgment at work',
        themes: const ['confidence', 'career'],
      ),
    ),
  ];
}

void main() {
  test('returns empty below archive evidence threshold', () {
    final result = const LifeChapterEngine().build(
      entries: [
        _entry(
          id: '1',
          at: DateTime(2026, 1, 1),
          line: 'I feel burnout and exhausted at work',
          themes: const ['health'],
        ),
      ],
    );
    expect(result.hasMinimumArchiveEvidence, isFalse);
    expect(result.chapters, isEmpty);
  });

  test('groups chronological periods into evidence-backed chapters', () {
    final result = const LifeChapterEngine().build(
      entries: _burnoutThenConfidenceArc(),
    );

    expect(result.hasMinimumArchiveEvidence, isTrue);
    expect(result.hasChapters, isTrue);
    expect(result.chapters.length, greaterThanOrEqualTo(2));

    final burnout = result.chapters
        .where((c) => c.title == 'Burnout Period')
        .toList();
    expect(burnout, isNotEmpty);
    expect(burnout.first.dominantThemes, isNotEmpty);
    expect(burnout.first.keyBeliefs, isNotEmpty);
    expect(burnout.first.importantQuotes.length, greaterThanOrEqualTo(1));
    expect(burnout.first.evidenceIds.length, greaterThanOrEqualTo(2));

    final rebuild = result.chapters
        .where((c) => c.title == 'Confidence Rebuild')
        .toList();
    expect(rebuild, isNotEmpty);
  });

  test('LifeChapter round-trips JSON', () {
    final chapter = LifeChapter(
      id: 'chapter-1',
      title: 'Career Transition',
      startDate: DateTime.utc(2025, 1, 1),
      endDate: DateTime.utc(2025, 6, 1),
      dominantThemes: ['Career', 'Networking'],
      keyBeliefs: ['Networking changed my career'],
      importantQuotes: [
        LifeChapterQuote(quote: 'I hate networking', entryId: 'a'),
        LifeChapterQuote(quote: 'Networking changed my career', entryId: 'b'),
      ],
      evidenceIds: ['a', 'b'],
    );
    final parsed = LifeChapter.fromJson(chapter.toJson());
    expect(parsed?.title, 'Career Transition');
    expect(parsed?.importantQuotes.length, 2);
  });
}
