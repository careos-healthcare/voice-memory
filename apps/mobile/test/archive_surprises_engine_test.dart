import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_engine.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 40,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 3,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: themes.isNotEmpty ? themes.first : '',
    ),
  );
}

void main() {
  const engine = ArchiveSurprisesEngine();

  test('theme dominance gap uses percents and evidence', () {
    final entries = <JournalEntry>[
      for (var i = 0; i < 12; i++)
        _entry(
          id: 'w$i',
          at: DateTime.utc(2026, 1, 5 + i),
          transcript:
              'My manager expects faster delivery on the roadmap and I am behind on quarterly goals at work.',
          themes: const ['career'],
        ),
      for (var i = 0; i < 2; i++)
        _entry(
          id: 'r$i',
          at: DateTime.utc(2026, 2, 5 + i),
          transcript:
              'I want to show up for my partner but tonight was about listening.',
          themes: const ['relationships'],
        ),
    ];

    final view = engine.build(entries: entries);
    expect(view.hasObservations, isTrue);
    final gap = view.observations.firstWhere(
      (o) => o.kind == ArchiveSurpriseKind.themeDominanceGap,
    );
    expect(gap.observation, contains('%'));
    expect(gap.observation, contains('Career'));
    expect(gap.observation, contains('Relationships'));
    expect(gap.evidenceEntryIds.length, greaterThanOrEqualTo(3));
    expect(gap.observation.toLowerCase(), isNot(contains('you focus on')));
  });

  test('theme cessation names last active month', () {
    final entries = <JournalEntry>[
      for (var i = 0; i < 5; i++)
        _entry(
          id: 'c1_$i',
          at: DateTime.utc(2026, 1, 10 + i),
          transcript:
              'My confidence is shaky and I doubt my judgment at work today.',
          themes: const ['confidence'],
        ),
      for (var i = 0; i < 5; i++)
        _entry(
          id: 'c2_$i',
          at: DateTime.utc(2026, 2, 10 + i),
          transcript:
              'My confidence is shaky and I doubt my judgment at work today.',
          themes: const ['confidence'],
        ),
      for (var i = 0; i < 6; i++)
        _entry(
          id: 'n$i',
          at: DateTime.utc(2026, 4, 10 + i),
          transcript:
              'I replay conversations until I feel certain about what someone meant.',
          themes: const ['avoidance'],
        ),
    ];

    final view = engine.build(entries: entries);
    final cessation = view.observations.where(
      (o) => o.kind == ArchiveSurpriseKind.themeStoppedMentioning,
    );
    expect(cessation, isNotEmpty);
    expect(cessation.first.observation, contains('stopped mentioning'));
    expect(cessation.first.evidenceEntryIds, isNotEmpty);
  });

  test('repeated decision loop requires multi-week spread', () {
    final entries = <JournalEntry>[];
    for (var w = 0; w < 4; w++) {
      for (var d = 0; d < 2; d++) {
        entries.add(
          _entry(
            id: 'loop${w}_$d',
            at: DateTime.utc(2026, 1, 1 + w * 7 + d),
            transcript:
                'I revisit the same hiring decision every week and keep postponing it.',
            themes: const ['career', 'money'],
          ),
        );
      }
    }
    for (var i = 0; i < 4; i++) {
      entries.add(
        _entry(
          id: 'fill$i',
          at: DateTime.utc(2026, 2, 10 + i),
          transcript:
              'Team standup today was fine and we aligned on priorities for the sprint.',
          themes: const ['career'],
        ),
      );
    }

    final view = engine.build(entries: entries);
    final loop = view.observations.where(
      (o) => o.kind == ArchiveSurpriseKind.repeatedDecisionLoop,
    );
    expect(loop, isNotEmpty);
    expect(loop.first.observation, contains('week'));
    expect(loop.first.evidenceCount, greaterThanOrEqualTo(3));
  });

  test('stated importance gap when theme claimed but rare', () {
    final entries = <JournalEntry>[
      for (var i = 0; i < 10; i++)
        _entry(
          id: 'work$i',
          at: DateTime.utc(2026, 2, 1 + i),
          transcript:
              'Work delivery pressure dominates my week and the roadmap never slows down.',
          themes: const ['career'],
        ),
      _entry(
        id: 'rel1',
        at: DateTime.utc(2026, 2, 20),
        transcript:
            'Relationships matter most to me but I struggle to show up for my partner.',
        themes: const ['relationships'],
      ),
      _entry(
        id: 'rel2',
        at: DateTime.utc(2026, 2, 22),
        transcript:
            'My family and partner matter most to me even when work is loud this week.',
        themes: const ['relationships'],
      ),
      _entry(
        id: 'rel3',
        at: DateTime.utc(2026, 2, 24),
        transcript:
            'Relationships matter most to me when I am honest about capacity.',
        themes: const ['relationships'],
      ),
    ];

    final view = engine.build(entries: entries);
    final gap = view.observations.where(
      (o) => o.kind == ArchiveSurpriseKind.statedImportanceGap,
    );
    expect(gap, isNotEmpty);
    expect(gap.first.observation, contains('important'));
    expect(gap.first.evidenceEntryIds.length, greaterThanOrEqualTo(3));
  });

  test('filters generic banned fragments', () {
    final view = engine.build(
      entries: List.generate(
        12,
        (i) => _entry(
          id: 'g$i',
          at: DateTime.utc(2026, 3, i + 1),
          transcript:
              'I keep avoiding difficult conversations at work and it affects my career growth daily.',
          themes: const ['career', 'avoidance'],
        ),
      ),
    );
    for (final o in view.observations) {
      expect(o.observation.toLowerCase(), isNot(contains('you focus on')));
      expect(
        o.observation.toLowerCase(),
        isNot(contains('forming from reflections')),
      );
    }
  });
}