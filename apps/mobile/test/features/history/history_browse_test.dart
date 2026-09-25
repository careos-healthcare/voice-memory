import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/features/history/history_views.dart';
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryMoment _moment({
  required String id,
  required DateTime at,
  String transcript = 'a walk',
  String? mood,
  String? place,
  double? latitude,
  double? longitude,
}) {
  return HistoryMoment(
    id: id,
    createdAt: at,
    transcript: transcript,
    mood: mood,
    place: place,
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  test('on this day keeps the same month and day from earlier years', () {
    expect(OnThisDayQuery.sql, contains("strftime('%m-%d', created_at)"));
    final now = DateTime(2026, 9, 25);
    final matches = OnThisDayQuery.match([
      _moment(id: 'old', at: DateTime(2024, 9, 25)),
      _moment(id: 'today', at: DateTime(2026, 9, 25)),
      _moment(id: 'other', at: DateTime(2024, 9, 26)),
    ], now);
    expect(matches.map((entry) => entry.id), ['old']);
  });

  testWidgets('calendar day shows a count and a mood', (tester) async {
    CalendarDaySummary? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarMonthView(
            month: DateTime(2026, 9),
            entries: [
              _moment(id: 'a', at: DateTime(2026, 9, 3), mood: 'calm'),
              _moment(id: 'b', at: DateTime(2026, 9, 3)),
            ],
            onDay: (day) => opened = day,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('calendar_count_3')), findsOneWidget);
    expect(find.byKey(const Key('calendar_mood_3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_day_3')));
    expect(opened?.count, 2);
  });

  test('nearby places share one pin', () {
    final pins = EntryMapClusters.cluster([
      _moment(id: 'a', at: DateTime(2026, 9, 1), latitude: 51.51, longitude: -0.12, place: 'Home'),
      _moment(id: 'b', at: DateTime(2026, 9, 2), latitude: 51.52, longitude: -0.11),
    ]);
    expect(pins, hasLength(1));
    expect(pins.single.label, 'Home');
  });

  test('printable journal starts a chapter for the month', () async {
    final bytes = await BookExporter.render(
      entries: [
        _moment(
          id: 'a',
          at: DateTime(2026, 3, 8),
          transcript: 'the river was high',
          mood: 'quiet',
          place: 'bridge',
        ),
      ],
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 12, 31),
    );
    expect(bytes, isNotEmpty);
    expect(_pdfWords(bytes), contains('2026-03'));
    expect(_pdfWords(bytes), contains('(the)'));
    expect(_pdfWords(bytes), contains('(river)'));
  });
}

String _pdfWords(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final buffer = StringBuffer(raw);
  final streamPattern = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
  for (final match in streamPattern.allMatches(raw)) {
    try {
      final inflated = zlib.decode(latin1.encode(match.group(1)!));
      buffer.write(latin1.decode(inflated, allowInvalid: true));
    } on FormatException {
      // Non-deflate streams are ignored.
    }
  }
  return buffer.toString();
}
