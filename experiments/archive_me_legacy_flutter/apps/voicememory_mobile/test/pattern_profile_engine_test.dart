import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_profile/pattern_profile_engine.dart';

KeyMoment _moment(
  String id,
  DateTime date, {
  String? patternTitle,
  String? resultHint,
}) => KeyMoment(
  id: id,
  date: date,
  title: 'Moment $id',
  originalText: 'text',
  shortSummary: 'text',
  patternTitle: patternTitle,
  resultHint: resultHint,
);

ArchiveMemorySummary _summary({String? nextCheck}) => ArchiveMemorySummary(
  id: 's1',
  patternTitle: 'Pressure before yes',
  primaryMemoryLine: 'You often say yes before checking in.',
  basedOnMomentCount: 4,
  basedOnWeekCount: 2,
  clarityLabel: 'Clear pattern',
  nextCheck: nextCheck,
);

PatternMap _map({String? nextCheck}) => PatternMap(
  patternTitle: 'Pressure before yes',
  seenCount: 4,
  confidenceLabel: 'Getting clearer',
  nextCheck: nextCheck,
);

PatternMemory _memory({String? nextCheck, int checkIns = 4}) => PatternMemory(
  id: 'p1',
  patternTitle: 'Memory pattern title',
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 6, 1),
  checkInCount: checkIns,
  nextBestQuestion: nextCheck,
);

void main() {
  test('returns null without pattern data', () {
    expect(buildPatternProfile(keyMoments: const []), isNull);
  });

  test('builds from summary', () {
    final profile = buildPatternProfile(
      summary: _summary(),
      keyMoments: [
        _moment(
          'a',
          DateTime(2026, 6, 1),
          patternTitle: 'Pressure before yes',
          resultHint: 'lighter',
        ),
      ],
    );
    expect(profile, isNotNull);
    expect(profile!.patternTitle, 'Pressure before yes');
    expect(profile.hasMemorySummary, isTrue);
  });

  test('builds from memory map timeline fallback title priority', () {
    final fromMemory = buildPatternProfile(
      memory: _memory(),
      keyMoments: const [],
    );
    expect(fromMemory!.patternTitle, 'Memory pattern title');

    final fromMap = buildPatternProfile(map: _map(), keyMoments: const []);
    expect(fromMap!.patternTitle, 'Pressure before yes');

    final fromTimeline = buildPatternProfile(
      timeline: ArchiveEvolutionTimeline(
        patternTitle: 'Timeline pattern',
        events: const [],
        eventCount: 0,
      ),
      keyMoments: const [],
    );
    expect(fromTimeline!.patternTitle, 'Timeline pattern');
  });

  test('nextCheck priority works', () {
    final profile = buildPatternProfile(
      summary: _summary(nextCheck: 'Summary check'),
      map: _map(nextCheck: 'Map check'),
      timeline: ArchiveEvolutionTimeline(
        patternTitle: 'Pressure before yes',
        events: const [],
        eventCount: 0,
        nextCheck: 'Timeline check',
      ),
      memory: _memory(nextCheck: 'Memory check'),
      keyMoments: const [],
    );
    expect(profile!.nextCheck, 'Summary check');

    final withoutSummary = buildPatternProfile(
      map: _map(nextCheck: 'Map check'),
      timeline: ArchiveEvolutionTimeline(
        patternTitle: 'Pressure before yes',
        events: const [],
        eventCount: 0,
        nextCheck: 'Timeline check',
      ),
      memory: _memory(nextCheck: 'Memory check'),
      keyMoments: const [],
    );
    expect(withoutSummary!.nextCheck, 'Map check');
  });

  test('clarityLabel priority works', () {
    final profile = buildPatternProfile(
      summary: _summary(),
      map: _map(),
      keyMoments: const [],
    );
    expect(profile!.clarityLabel, 'Clear pattern');

    final early = buildPatternProfile(
      memory: _memory(checkIns: 1),
      keyMoments: [
        _moment(
          'a',
          DateTime(2026, 6, 1),
          patternTitle: 'Memory pattern title',
        ),
      ],
    );
    expect(early!.clarityLabel, 'Early read');
  });

  test('related key moments are filtered by pattern title', () {
    final profile = buildPatternProfile(
      summary: _summary(),
      keyMoments: [
        _moment(
          'match',
          DateTime(2026, 6, 2),
          patternTitle: 'Pressure before yes',
        ),
        _moment('other', DateTime(2026, 6, 1), patternTitle: 'Other pattern'),
      ],
    );
    expect(profile!.keyMoments.map((m) => m.id), ['match']);
  });

  test('preview list is capped at 5', () {
    final profile = buildPatternProfile(
      summary: _summary(),
      keyMoments: List.generate(
        8,
        (i) => _moment(
          'm$i',
          DateTime(2026, 6, i + 1),
          patternTitle: 'Pressure before yes',
        ),
      ),
    );
    expect(profile!.keyMoments.length, 5);
  });
}
