import 'package:archiveme_mobile/features/archive/views/book_export_view.dart';
import 'package:archiveme_mobile/features/archive/views/calendar_view.dart';
import 'package:archiveme_mobile/features/archive/views/history_hub_view.dart';
import 'package:archiveme_mobile/features/archive/views/map_view.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  String transcript = 'the river was high',
  double? latitude,
  double? longitude,
  String? place,
  String? audio,
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 8,
    localAudioPath: audio,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    display: JournalDisplayMetadata(
      locationLabel: place,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a marked calendar day lists that day', (tester) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarView(
            now: DateTime(2026, 9, 26),
            entries: [
              _entry(id: 'a', at: DateTime(2026, 9, 3)),
            ],
            onOpenEntry: (id) => opened = id,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('calendar_mark_3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_day_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_day_entries')), findsOneWidget);
    expect(find.text('the river was high'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_entry_a')));
    await tester.pumpAndSettle();
    expect(opened, 'a');
  });

  testWidgets('on this day groups an earlier year and offers playback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OnThisDayView(
            now: DateTime(2026, 9, 26),
            entries: [
              _entry(
                id: 'then',
                at: DateTime(2024, 9, 26),
                audio: '/tmp/then.m4a',
              ),
              _entry(id: 'today', at: DateTime(2026, 9, 26)),
            ],
          ),
        ),
      ),
    );
    expect(find.text('2 Years Ago - 2024'), findsOneWidget);
    expect(find.byKey(const Key('on_this_day_then')), findsOneWidget);
    expect(find.byKey(const Key('on_this_day_today')), findsNothing);
    expect(find.byKey(const Key('on_this_day_play_then')), findsOneWidget);
  });

  testWidgets('a map pin shows the moment and opens it', (tester) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MapView(
            entries: [
              _entry(
                id: 'home',
                at: DateTime(2026, 9, 1),
                place: 'Home',
                latitude: 51.5,
                longitude: -0.12,
              ),
              _entry(
                id: 'none',
                at: DateTime(2026, 9, 2),
                transcript: 'no place',
              ),
            ],
            onOpenEntry: (id) => opened = id,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.place), findsOneWidget);
    await tester.tap(find.byIcon(Icons.place));
    await tester.pumpAndSettle();
    expect(find.text('the river was high'), findsOneWidget);
    expect(find.text('no place'), findsNothing);
    await tester.tap(find.byKey(const Key('map_open_home')));
    await tester.pumpAndSettle();
    expect(opened, 'home');
  });

  testWidgets('printable journal shares the chosen range', (tester) async {
    DateTime? start;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookExportView(
            now: DateTime(2026, 9, 26),
            entries: [
              _entry(id: 'a', at: DateTime(2026, 3, 8)),
            ],
            onShare: (from, _) async => start = from,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('export_printable_journal')));
    await tester.pump();
    expect(start, DateTime(2026, 1, 1));

    await tester.tap(find.byKey(const Key('book_range_six_months')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('export_printable_journal')));
    await tester.pump();
    expect(start, DateTime(2026, 3, 26));
  });

  testWidgets('the archive row opens the calendar with the saved moments', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HistoryHubStrip(
            entries: [
              _entry(id: 'a', at: DateTime(2026, 9, 3)),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('history_open_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_mark_3')), findsOneWidget);
  });
}
