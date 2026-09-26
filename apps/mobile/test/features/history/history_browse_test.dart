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
    expect(OnThisDayQuery.sql, contains('is_silenced_from_on_this_day = 0'));
    final now = DateTime(2026, 9, 25);
    final matches = OnThisDayQuery.match([
      _moment(id: 'old', at: DateTime(2024, 9, 25)),
      _moment(id: 'today', at: DateTime(2026, 9, 25)),
      _moment(id: 'other', at: DateTime(2024, 9, 26)),
    ], now);
    expect(matches.map((entry) => entry.id), ['old']);
    final hidden = OnThisDayQuery.match(
      [
        _moment(id: 'old', at: DateTime(2024, 9, 25)),
        _moment(id: 'quiet', at: DateTime(2023, 9, 25)),
      ],
      now,
      silencedIds: {'quiet'},
    );
    expect(hidden.map((entry) => entry.id), ['old']);
  });

  testWidgets('calendar day is shaded without a count', (tester) async {
    CalendarDaySummary? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CalendarMonthView(
            month: DateTime(2026, 9),
            entries: [
              HistoryMoment(
                id: 'a',
                createdAt: DateTime(2026, 9, 3),
                transcript: 'a walk',
                mood: 'calm',
                durationSeconds: 60,
              ),
              HistoryMoment(
                id: 'b',
                createdAt: DateTime(2026, 9, 3),
                transcript: 'another',
                durationSeconds: 120,
              ),
            ],
            onDay: (day) => opened = day,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('calendar_count_3')), findsNothing);
    expect(find.byKey(const Key('calendar_mood_3')), findsOneWidget);
    expect(find.byKey(const Key('calendar_heat_3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_day_3')));
    expect(opened?.count, 2);
    expect(opened?.volume, 3);
  });

  test('heatmap uses four shades and skips an empty day', () {
    expect(CalendarHeatmap.tier(0, 100), 0);
    expect(CalendarHeatmap.tier(10, 100), 1);
    expect(CalendarHeatmap.tier(50, 100), 2);
    expect(CalendarHeatmap.tier(75, 100), 3);
    expect(CalendarHeatmap.tier(100, 100), 4);
    final primary = const Color(0xFF2563EB);
    expect(CalendarHeatmap.shade(primary, 1).a, closeTo(0.2, 0.01));
    expect(CalendarHeatmap.shade(primary, 4).a, closeTo(1, 0.01));
    expect(CalendarHeatmap.shade(primary, 0).a, 0);
  });

  test('a longer recording is a heavier day than a short note', () {
    final days = CalendarMonth.days(
      month: DateTime(2026, 9),
      entries: [
        HistoryMoment(
          id: 'short',
          createdAt: DateTime(2026, 9, 2),
          transcript: 'hi',
          durationSeconds: 60,
        ),
        HistoryMoment(
          id: 'long',
          createdAt: DateTime(2026, 9, 4),
          transcript: 'hi',
          durationSeconds: 15 * 60,
        ),
      ],
    );
    final light = days.firstWhere((day) => day.day == 2);
    final heavy = days.firstWhere((day) => day.day == 4);
    expect(light.volume, 1);
    expect(heavy.volume, 15);
    expect(
      CalendarHeatmap.tier(heavy.volume, 15),
      greaterThan(CalendarHeatmap.tier(light.volume, 15)),
    );
    expect(CalendarHeatmap.tier(0, 15), 0);
    expect(CalendarHeatmap.tier(15, 15), 4);
  });

  test('display coordinates round to two decimal places', () {
    expect(EntryMapCoordinates.coarse(51.5074), 51.51);
    expect(EntryMapCoordinates.coarse(-0.126), -0.13);
    expect(EntryMapCoordinates.coarse(51.5), 51.5);
    expect(EntryMapCoordinates.coarse(-0.12).toString(), '-0.12');
    final pins = EntryMapClusters.cluster([
      _moment(
        id: 'a',
        at: DateTime(2026, 9, 1),
        latitude: 51.5074,
        longitude: -0.126,
      ),
    ]);
    expect(pins.single.latitude, 51.51);
    expect(pins.single.longitude, -0.13);
  });

  test('nearby places share one pin', () {
    final pins = EntryMapClusters.cluster([
      _moment(
        id: 'a',
        at: DateTime(2026, 9, 1),
        latitude: 51.51,
        longitude: -0.12,
        place: 'Home',
      ),
      _moment(
        id: 'b',
        at: DateTime(2026, 9, 2),
        latitude: 51.52,
        longitude: -0.11,
      ),
    ]);
    expect(pins, hasLength(1));
    expect(pins.single.label, 'Home');
  });

  test('identical low-accuracy coordinates share one pin', () {
    final pins = EntryMapClusters.cluster([
      _moment(
        id: 'a',
        at: DateTime(2026, 9, 1),
        latitude: 51.5,
        longitude: -0.12,
      ),
      _moment(
        id: 'b',
        at: DateTime(2026, 9, 2),
        latitude: 51.5,
        longitude: -0.12,
      ),
    ]);
    expect(pins, hasLength(1));
    expect(pins.single.isCluster, isTrue);
    expect(pins.single.entries.map((entry) => entry.id), ['a', 'b']);
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
    final words = _pdfWords(bytes);
    expect(words, contains('2026-03'));
    expect(words, contains('March'));
    expect(words, contains('the'));
    expect(words, contains('river'));
  });
}

String _pdfWords(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
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
  buffer.write(_decodedPdfText(buffer.toString()));
  return buffer.toString();
}

String _decodedPdfText(String pdf) {
  final maps = <Map<int, String>>[];
  for (final block in RegExp(
    r'beginbfchar([\s\S]*?)endbfchar',
  ).allMatches(pdf)) {
    final map = <int, String>{};
    for (final pair in RegExp(
      r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
    ).allMatches(block.group(1)!)) {
      final code = int.parse(pair.group(2)!, radix: 16);
      if (code == 0) continue;
      map[int.parse(pair.group(1)!, radix: 16)] = String.fromCharCode(code);
    }
    if (map.isNotEmpty) maps.add(map);
  }
  final buffer = StringBuffer();
  for (final map in maps) {
    for (final array in RegExp(r'\[(.*?)\]\s*TJ').allMatches(pdf)) {
      final word = StringBuffer();
      var any = false;
      for (final hex in RegExp(
        r'<([0-9A-Fa-f]+)>',
      ).allMatches(array.group(1)!)) {
        final raw = hex.group(1)!;
        if (raw.length % 4 != 0) continue;
        for (var index = 0; index < raw.length; index += 4) {
          final character =
              map[int.parse(raw.substring(index, index + 4), radix: 16)];
          if (character == null) continue;
          any = true;
          word.write(character);
        }
      }
      if (any) buffer.write('$word ');
    }
  }
  return buffer.toString();
}
