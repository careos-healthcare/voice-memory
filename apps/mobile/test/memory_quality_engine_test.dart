import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_engine.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveMemorySummary _summary({int momentCount = 0, String? changedLine}) =>
    ArchiveMemorySummary(
      id: 's1',
      patternTitle: 'Test pattern',
      primaryMemoryLine: 'Line',
      basedOnMomentCount: momentCount,
      basedOnWeekCount: 2,
      clarityLabel: 'Clear pattern',
      changedLine: changedLine,
    );

KeyMoment _moment(int day) => KeyMoment(
  id: 'm$day',
  date: DateTime(2026, 6, day),
  title: 'Moment',
  originalText: 'text',
  shortSummary: 'text',
  patternTitle: 'Test pattern',
);

void main() {
  test('earlyRead below 3 moments', () {
    final quality = buildMemoryQuality(summary: _summary(momentCount: 2));
    expect(quality.level, MemoryQualityLevel.earlyRead);
    expect(quality.label, 'Early read');
    expect(
      quality.helperText,
      'Record a few more moments to make this clearer.',
    );
  });

  test('gettingClearer at 3–4 moments', () {
    final at3 = buildMemoryQuality(summary: _summary(momentCount: 3));
    final at4 = buildMemoryQuality(summary: _summary(momentCount: 4));
    expect(at3.level, MemoryQualityLevel.gettingClearer);
    expect(at4.level, MemoryQualityLevel.gettingClearer);
    expect(at3.label, 'Getting clearer');
  });

  test('clearPattern at 5–9 moments', () {
    final at5 = buildMemoryQuality(summary: _summary(momentCount: 5));
    final at9 = buildMemoryQuality(summary: _summary(momentCount: 9));
    expect(at5.level, MemoryQualityLevel.clearPattern);
    expect(at9.level, MemoryQualityLevel.clearPattern);
    expect(at5.label, 'Clear pattern');
  });

  test('strongPattern at 10+ moments', () {
    final quality = buildMemoryQuality(summary: _summary(momentCount: 10));
    expect(quality.level, MemoryQualityLevel.strongPattern);
    expect(quality.label, 'Strong pattern');
    expect(quality.isStrong, isTrue);
  });

  test('changingPattern override only when count >= 3', () {
    final tooEarly = buildMemoryQuality(
      summary: _summary(momentCount: 2, changedLine: 'It changed recently.'),
    );
    expect(tooEarly.level, MemoryQualityLevel.earlyRead);

    final overridden = buildMemoryQuality(
      summary: _summary(momentCount: 5, changedLine: 'It changed recently.'),
    );
    expect(overridden.level, MemoryQualityLevel.changingPattern);
    expect(overridden.label, 'Changing pattern');
  });

  test('uses conservative max count across sources', () {
    final quality = buildMemoryQuality(
      summary: _summary(momentCount: 2),
      memory: PatternMemory(
        id: 'pm1',
        patternTitle: 'Test',
        createdAt: DateTime(2026, 6),
        updatedAt: DateTime(2026, 6),
        checkInCount: 6,
      ),
      keyMoments: [_moment(1), _moment(2), _moment(3)],
      map: const PatternMap(
        patternTitle: 'Test',
        seenCount: 4,
        confidenceLabel: 'Based on 4 check-ins',
      ),
    );
    expect(quality.momentCount, 6);
    expect(quality.level, MemoryQualityLevel.clearPattern);
  });

  test('weekCount from summary when available', () {
    final quality = buildMemoryQuality(summary: _summary(momentCount: 5));
    expect(quality.weekCount, 2);
  });

  test('weekCount from key moment span when summary weeks missing', () {
    final quality = buildMemoryQuality(keyMoments: [_moment(1), _moment(15)]);
    expect(quality.weekCount, greaterThanOrEqualTo(2));
  });

  test('progress changing triggers hasChangedRecently', () {
    final quality = buildMemoryQuality(
      summary: _summary(momentCount: 4),
      progress: PatternProgressMoment(
        id: 'p1',
        memoryId: 'pm1',
        type: PatternProgressType.changing,
        headline: 'Changing',
        body: 'Body',
        nextLine: 'Next',
        checkInCount: 4,
        shouldShow: true,
        createdAt: DateTime(2026, 6),
      ),
    );
    expect(quality.level, MemoryQualityLevel.changingPattern);
  });

  test('does not expose confidence language', () {
    final quality = buildMemoryQuality(summary: _summary(momentCount: 8));
    expect(quality.label.toLowerCase(), isNot(contains('confidence')));
    expect(quality.helperText.toLowerCase(), isNot(contains('confidence')));
    expect(quality.helperText.toLowerCase(), isNot(contains('ai ')));
  });
}