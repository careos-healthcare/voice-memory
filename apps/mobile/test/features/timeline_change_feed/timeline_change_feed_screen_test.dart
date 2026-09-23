import 'package:archiveme_mobile/features/timeline_change_feed/timeline_change_feed_providers.dart';
import 'package:archiveme_mobile/features/timeline_change_feed/timeline_change_feed_screen.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date range and section expansion notifiers keep their own state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(timelineDateRangeProvider.notifier).selectYear(2026);
    container.read(timelineDateRangeProvider.notifier).selectMonth(9);
    expect(container.read(timelineDateRangeProvider).year, 2026);
    expect(container.read(timelineDateRangeProvider).month, 9);

    container.read(timelineDateRangeProvider.notifier).selectYear(2025);
    expect(container.read(timelineDateRangeProvider).month, isNull);

    container.read(timelineSectionExpansionProvider.notifier).toggle('2026-9');
    expect(
      container.read(timelineSectionExpansionProvider).isExpanded('2026-9'),
      isFalse,
    );
    container.read(timelineSectionExpansionProvider.notifier).toggle('2026-9');
    expect(
      container.read(timelineSectionExpansionProvider).isExpanded('2026-9'),
      isTrue,
    );
  });

  testWidgets(
    'pins month headers and separates voice memories from text logs',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final entries = [
        _entry(
          'voice',
          DateTime.utc(2026, 9, 20),
          'Walked after lunch.',
          voice: true,
        ),
        _entry('note-0', DateTime.utc(2026, 9, 19), 'Wrote note 0.'),
        for (var i = 1; i < 8; i++)
          _entry('note-$i', DateTime.utc(2026, 9, i), 'Wrote note $i.'),
        _entry('older', DateTime.utc(2025, 1, 4), 'Last winter.'),
      ];

      await tester.pumpWidget(_host(entries));
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsWidgets);
      expect(find.text('September 2026'), findsOneWidget);
      expect(
        find.byKey(const Key('timeline_change_feed_voice_voice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline_change_feed_text_note-0')),
        findsOneWidget,
      );
      expect(find.text('0:12'), findsOneWidget);

      final voiceBox = tester.widget<DecoratedBox>(
        find.byKey(const Key('timeline_change_feed_voice_voice')),
      );
      final textBox = tester.widget<DecoratedBox>(
        find.byKey(const Key('timeline_change_feed_text_note-0')),
      );
      expect(
        (voiceBox.decoration as BoxDecoration).color,
        AppTokens.primary50,
      );
      expect(
        (textBox.decoration as BoxDecoration).color,
        AppTheme.light().colorScheme.surface,
      );

      await tester.drag(
        find.byKey(const Key('timeline_change_feed')),
        const Offset(0, -500),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('timeline_change_feed_header_2026-9')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('timeline_change_feed_all')), findsNothing);

      await tester.tap(
        find.byKey(const Key('timeline_change_feed_header_2026-9')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('timeline_change_feed_voice_voice')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('timeline_change_feed_year_2025')));
      await tester.pumpAndSettle();
      expect(find.text('January 2025'), findsOneWidget);
      expect(find.text('September 2026'), findsNothing);
      expect(find.text('Last winter.'), findsOneWidget);
    },
  );
}

Widget _host(List<JournalEntry> entries) {
  return ProviderScope(
    overrides: [
      timelineArchiveSourceProvider.overrideWithValue(
        TimelineArchiveSource(() async => entries),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const TimelineChangeFeedScreen(),
    ),
  );
}

JournalEntry _entry(
  String id,
  DateTime createdAt,
  String transcript, {
  bool voice = false,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: voice ? 12 : 0,
    localAudioPath: voice ? '/tmp/$id.m4a' : null,
    reflection: const Reflection(
      mood: 'steady',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}
