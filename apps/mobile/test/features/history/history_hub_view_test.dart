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
    expect(find.byKey(const Key('calendar_heat_3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_day_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_day_entries')), findsOneWidget);
    expect(find.text('the river was high'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_entry_a')));
    await tester.pumpAndSettle();
    expect(opened, 'a');
  });

  testWidgets('year view opens a month and a day sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarView(
            now: DateTime(2026, 3, 12),
            entries: [
              _entry(
                id: 'a',
                at: DateTime(2026, 3, 3),
                transcript: 'march day',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_year_view')), findsOneWidget);
    expect(find.byKey(const Key('calendar_year_month_3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar_year_3_day_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_day_entries')), findsOneWidget);
    expect(find.text('march day'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar_year_month_1')));
    await tester.pumpAndSettle();
    expect(find.text('January'), findsOneWidget);
    expect(find.byKey(const Key('calendar_month_view')), findsOneWidget);
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
    expect(find.text('2 years ago'), findsOneWidget);
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
            locationPermissionDenied: false,
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
    expect(find.byKey(const Key('map_area_51.5_-0.12')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map_area_51.5_-0.12')));
    await tester.pumpAndSettle();
    expect(find.text('the river was high'), findsOneWidget);
    expect(find.text('no place'), findsNothing);
    await tester.tap(find.byKey(const Key('map_open_home')));
    await tester.pumpAndSettle();
    expect(opened, 'home');
  });

  testWidgets('identical coordinates open a row of cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MapView(
            locationPermissionDenied: false,
            entries: [
              _entry(
                id: 'first',
                at: DateTime(2026, 9, 1),
                place: 'Home',
                latitude: 51.5,
                longitude: -0.12,
                transcript: 'first moment here',
              ),
              _entry(
                id: 'second',
                at: DateTime(2026, 9, 2),
                place: 'Home',
                latitude: 51.5,
                longitude: -0.12,
                transcript: 'second moment here',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.place), findsNothing);
    await tester.tap(find.byKey(const Key('map_cluster_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map_cluster_cards')), findsOneWidget);
    expect(find.text('first moment here'), findsOneWidget);
    expect(find.text('second moment here'), findsOneWidget);
    expect(find.text('View Entry'), findsNWidgets(2));
  });

  testWidgets('a map without coordinates explains location tagging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MapView(
            locationPermissionDenied: false,
            entries: [
              _entry(
                id: 'none',
                at: DateTime(2026, 9, 2),
                transcript: 'no place',
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Turn on places to see where your moments happened.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.place), findsNothing);
  });

  testWidgets('a permanently denied location permission covers the map', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MapView(
            locationPermissionDenied: true,
            entries: [
              _entry(
                id: 'home',
                at: DateTime(2026, 9, 1),
                place: 'Home',
                latitude: 51.5,
                longitude: -0.12,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('map_empty_state')), findsOneWidget);
    expect(find.byIcon(Icons.place), findsNothing);
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
    await tester.ensureVisible(
      find.byKey(const Key('export_printable_journal')),
    );
    await tester.tap(find.byKey(const Key('export_printable_journal')));
    await tester.pump();
    expect(start, DateTime(2026, 1, 1));

    await tester.tap(find.byKey(const Key('book_range_six_months')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('export_printable_journal')),
    );
    await tester.tap(find.byKey(const Key('export_printable_journal')));
    await tester.pump();
    expect(start, DateTime(2026, 3, 26));
    expect(
      find.text('Your year in your own words, printed.'),
      findsOneWidget,
    );
    expect(find.text('Print at Home (AirPrint)'), findsOneWidget);
    expect(
      find.text(
        'Include playable audio QR codes (requires temporary cloud upload)',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This temporarily pushes encrypted audio to the cloud to generate the link. Each link expires after 30 days.',
      ),
      findsOneWidget,
    );
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('book_audio_qr_toggle')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('print at home uses the chosen year', (tester) async {
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
            onPrint: (from, _) async => start = from,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('book_print_at_home')));
    await tester.tap(find.byKey(const Key('book_print_at_home')));
    await tester.pump();
    expect(start, DateTime(2026, 1, 1));
    expect(
      find.text('A small book of this year, ready to keep or give as a gift.'),
      findsOneWidget,
    );
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
    expect(find.byKey(const Key('calendar_heat_3')), findsOneWidget);
  });

  testWidgets('the month label opens the calendar on that month', (
    tester,
  ) async {
    final month = DateTime(2026, 3, 15);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const Key('archive_calendar_month'),
                onPressed: () => openArchiveCalendar(
                  context,
                  entries: [
                    _entry(id: 'march', at: DateTime(2026, 3, 4)),
                  ],
                  month: month,
                ),
                child: const Text('March'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('archive_calendar_month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_month_view')), findsOneWidget);
    expect(find.text('March'), findsWidgets);
    expect(find.byKey(const Key('calendar_month_label')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('calendar_month_label'))).data,
      'March',
    );
    expect(find.byKey(const Key('calendar_day_4')), findsOneWidget);
  });
}
