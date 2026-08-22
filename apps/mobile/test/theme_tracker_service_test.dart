import 'package:archiveme_mobile/features/theme_tracking/theme_track.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String text,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$text — enough transcript characters for theme tracking here.',
    durationSeconds: 20,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: text,
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('track surfaces canonical themes with frequency and trend', () {
    final entries = [
      _entry(
        id: '1',
        at: DateTime(2025),
        text: 'I need approval from my manager',
        themes: const ['approval'],
      ),
      _entry(
        id: '2',
        at: DateTime(2025, 3),
        text: 'Still seeking approval in meetings',
      ),
      _entry(
        id: '3',
        at: DateTime(2026),
        text: 'My confidence is growing at work',
        themes: const ['confidence'],
      ),
      _entry(
        id: '4',
        at: DateTime(2026, 3),
        text: 'I trust my judgment on career moves',
        themes: const ['career'],
      ),
    ];

    final result = const ThemeTrackerService().track(
      entries: entries,
      baselineCounts: {'approval': 1},
    );

    expect(result.hasThemes, isTrue);
    final approval = result.topThemes.firstWhere((t) => t.name == 'Approval');
    expect(approval.frequency, 2);
    expect(approval.trend, ThemeTrend.up);
    expect(approval.trendGlyph, '↑');

    final confidence = result.topThemes.firstWhere(
      (t) => t.name == 'Confidence',
    );
    expect(confidence.frequency, greaterThanOrEqualTo(1));
  });

  test('detects avoidance keyword in transcript', () {
    final result = const ThemeTrackerService().track(
      entries: [
        _entry(
          id: 'a',
          at: DateTime(2026),
          text: 'I keep avoiding difficult conversations',
        ),
        _entry(
          id: 'b',
          at: DateTime(2026, 2),
          text: 'Avoidance is my default when stressed',
        ),
      ],
    );
    expect(
      result.topThemes.any((t) => t.name == 'Avoidance' && t.frequency >= 2),
      isTrue,
    );
  });

  test('ArchiveTheme serializes for future sync', () {
    const theme = ArchiveTheme(
      name: 'Career',
      frequency: 3,
      trend: ThemeTrend.down,
    );
    final parsed = ArchiveTheme.fromJson(theme.toJson());
    expect(parsed?.trend, ThemeTrend.down);
    expect(parsed?.trendGlyph, '↓');
  });
}