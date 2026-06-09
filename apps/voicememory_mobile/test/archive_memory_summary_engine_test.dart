import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_memory_summary_engine.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';

PatternMemory _memory({
  String title = 'Taking responsibility before asking for help',
  int checkInCount = 4,
  List<String> before = const [],
  List<String> helped = const [],
  List<String> harder = const [],
  String? nextBestQuestion,
  PatternMemoryStatus status = PatternMemoryStatus.active,
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    PatternMemory(
      id: 'm1',
      patternTitle: title,
      createdAt: createdAt ?? DateTime(2026, 5, 4),
      updatedAt: updatedAt ?? DateTime(2026, 5, 25),
      checkInCount: checkInCount,
      commonBeforeMoments: before,
      helpedMoments: helped,
      harderMoments: harder,
      nextBestQuestion: nextBestQuestion,
      status: status,
    );

void main() {
  test('returns null below 3 usable moments/check-ins', () {
    final summary = buildArchiveMemorySummary(memory: _memory(checkInCount: 2));
    expect(summary, isNull);
  });

  test('builds the primary memory line from the pattern title', () {
    final summary = buildArchiveMemorySummary(memory: _memory(checkInCount: 4));
    expect(summary, isNotNull);
    // Gerund title normalized to a natural base verb: "Taking" -> "take".
    expect(summary!.primaryMemoryLine,
        'You often take responsibility before asking for help.');
  });

  test('normalizes common gerund pattern titles to natural copy', () {
    String line(String title) =>
        buildArchiveMemorySummary(memory: _memory(title: title))!
            .primaryMemoryLine;

    expect(line('Taking responsibility before asking for help'),
        'You often take responsibility before asking for help.');
    expect(line('Trying to prove you are enough'),
        'You often try to prove you are enough.');
    expect(line('Putting off what matters'),
        'You often put off what matters.');
    expect(line('Running on empty'), 'You often run on empty.');
    expect(line('Carrying it alone'), 'You often carry it alone.');
    expect(line('Avoiding hard conversations'),
        'You often avoid hard conversations.');
    expect(line('Feeling behind'), 'You often feel behind.');
    expect(line('Worrying about what they think'),
        'You often worry about what they think.');
    expect(line('Replaying old conversations'),
        'You often replay old conversations.');
    expect(line('Saying yes too fast'), 'You often say yes too fast.');
  });

  test('falls back to lower-casing the first letter when no verb matches', () {
    final summary =
        buildArchiveMemorySummary(memory: _memory(title: 'Pressure at work'));
    expect(summary!.primaryMemoryLine, 'You often pressure at work.');
  });

  test('falls back to a generic primary line without a title', () {
    final summary = buildArchiveMemorySummary(
      memory: _memory(title: '', checkInCount: 5),
    );
    expect(summary!.primaryMemoryLine, 'One pattern keeps showing up.');
  });

  test('includes starts-before when available and strips leading "before"', () {
    final summary = buildArchiveMemorySummary(
      memory: _memory(before: const ['before saying yes']),
    );
    expect(summary!.startsBeforeLine, 'It often starts before: saying yes.');
  });

  test('prefers the pattern map starts-before over memory', () {
    final summary = buildArchiveMemorySummary(
      memory: _memory(before: const ['from memory']),
      patternMap: const PatternMap(
        patternTitle: 'Taking responsibility before asking for help',
        seenCount: 4,
        usuallyStartsBefore: 'a hard conversation',
        confidenceLabel: 'Based on 4 check-ins',
      ),
    );
    expect(summary!.startsBeforeLine,
        'It often starts before: a hard conversation.');
  });

  test('includes helped and heavier only when known', () {
    final withHelp = buildArchiveMemorySummary(
      memory: _memory(helped: const ['pausing before answering']),
    );
    expect(withHelp!.helpedLine,
        'It has felt lighter when: pausing before answering.');
    expect(withHelp.heavierLine, isNull);

    final withHeavier = buildArchiveMemorySummary(
      memory: _memory(harder: const ['taking it on alone']),
    );
    expect(withHeavier!.heavierLine,
        'It has felt heavier when: taking it on alone.');
    expect(withHeavier.helpedLine, isNull);
  });

  test('adds the changed line only when progress or weekly says changed', () {
    final steady = buildArchiveMemorySummary(
      memory: _memory(),
      progress: PatternProgressMoment(
        id: 'p1',
        memoryId: 'm1',
        createdAt: DateTime(2026, 5, 25),
        type: PatternProgressType.stillRepeating,
        headline: '',
        body: '',
        nextLine: '',
        checkInCount: 4,
        shouldShow: true,
      ),
    );
    expect(steady!.changedLine, isNull);

    final changed = buildArchiveMemorySummary(
      memory: _memory(),
      progress: PatternProgressMoment(
        id: 'p1',
        memoryId: 'm1',
        createdAt: DateTime(2026, 5, 25),
        type: PatternProgressType.changing,
        headline: '',
        body: '',
        nextLine: '',
        checkInCount: 4,
        shouldShow: true,
      ),
    );
    expect(changed!.changedLine, 'This pattern has changed recently.');
  });

  test('clarity labels at 3, 5, and 10 moments', () {
    expect(
      buildArchiveMemorySummary(memory: _memory(checkInCount: 3))!.clarityLabel,
      'Getting clearer',
    );
    expect(
      buildArchiveMemorySummary(memory: _memory(checkInCount: 5))!.clarityLabel,
      'Clear pattern',
    );
    expect(
      buildArchiveMemorySummary(memory: _memory(checkInCount: 10))!.clarityLabel,
      'Strong pattern',
    );
  });

  test('next check resolves from result, then map, then memory', () {
    final fromMemory = buildArchiveMemorySummary(
      memory: _memory(nextBestQuestion: 'From memory?'),
    );
    expect(fromMemory!.nextCheck, 'From memory?');

    final fromMap = buildArchiveMemorySummary(
      memory: _memory(nextBestQuestion: 'From memory?'),
      patternMap: const PatternMap(
        patternTitle: 'Taking responsibility before asking for help',
        seenCount: 4,
        nextCheck: 'From map?',
        confidenceLabel: 'Based on 4 check-ins',
      ),
    );
    expect(fromMap!.nextCheck, 'From map?');
  });

  test('counts conservatively and derives weeks from first/last seen', () {
    final summary = buildArchiveMemorySummary(
      memory: _memory(
        checkInCount: 4,
        createdAt: DateTime(2026, 5, 4),
        updatedAt: DateTime(2026, 5, 25),
      ),
      patternMap: const PatternMap(
        patternTitle: 'Taking responsibility before asking for help',
        seenCount: 8,
        confidenceLabel: 'Based on 8 check-ins',
      ),
    );
    // Conservative: takes the strongest single source (8), never the sum.
    expect(summary!.basedOnMomentCount, 8);
    expect(summary.basedOnWeekCount, 3);
  });

  test('uses key moments to reach the threshold and weekly recap title', () {
    final moments = [
      KeyMoment(
        id: 'k1',
        date: DateTime(2026, 5, 20),
        title: 'A pattern showed up again',
        originalText: 'text',
        shortSummary: 'summary',
        patternTitle: 'Saying yes too fast',
        source: KeyMomentSource.checkIn,
      ),
      KeyMoment(
        id: 'k2',
        date: DateTime(2026, 5, 21),
        title: 'A pattern showed up again',
        originalText: 'text',
        shortSummary: 'summary',
        patternTitle: 'Saying yes too fast',
        source: KeyMomentSource.checkIn,
      ),
      KeyMoment(
        id: 'k3',
        date: DateTime(2026, 5, 22),
        title: 'A pattern showed up again',
        originalText: 'text',
        shortSummary: 'summary',
        patternTitle: 'Saying yes too fast',
        source: KeyMomentSource.checkIn,
      ),
    ];
    final summary = buildArchiveMemorySummary(
      keyMoments: moments,
      weeklyRecap: WeeklyPatternRecap(
        id: 'w1',
        memoryId: 'm1',
        createdAt: DateTime(2026, 5, 22),
        weekStart: DateTime(2026, 5, 18),
        weekEnd: DateTime(2026, 5, 24),
        type: WeeklyPatternRecapType.repeated,
        patternTitle: 'Saying yes too fast',
        headline: '',
        body: '',
        checkInCount: 3,
        shouldShow: true,
      ),
    );
    expect(summary, isNotNull);
    expect(summary!.basedOnMomentCount, 3);
    expect(summary.patternTitle, 'Saying yes too fast');
    expect(summary.primaryMemoryLine, 'You often say yes too fast.');
  });
}
