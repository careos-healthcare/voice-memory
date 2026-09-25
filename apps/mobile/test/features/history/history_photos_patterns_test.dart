import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/features/insights/theme_frequency.dart';
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:archiveme_mobile/features/map/entry_map_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recurring words name the pair and the entries', () {
    final themes = ThemeFrequency.analyze([
      (id: 'a', text: 'sleep was short and stress was high'),
      (id: 'b', text: 'stress again after too little sleep'),
      (id: 'c', text: 'the market was loud'),
    ]);
    expect(themes, isNotEmpty);
    expect(
      themes.first.sentence,
      "You frequently mention 'sleep' and 'stress' together",
    );
    expect(themes.first.entryIds, ['a', 'b']);
  });

  test('journal images round-trip as a list of paths', () {
    final entry = JournalEntry(
      id: 'river',
      createdAt: DateTime.utc(2026, 3, 8),
      transcript: 'the river was high',
      durationSeconds: 3,
      reflection: const Reflection(
        mood: 'quiet',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
    final encoded = JournalEntry.fromJson({
      ...entry.toJson(),
      'images': ['/tmp/river.jpg', 'https://example.com/bridge.png'],
    });
    expect(encoded.images, [
      '/tmp/river.jpg',
      'https://example.com/bridge.png',
    ]);
    expect(encoded.toJson()['images'], encoded.images);
  });

  test('printable journal keeps the transcript when a photo is attached', () async {
    final dir = await Directory.systemTemp.createTemp('journal_photo_');
    final photo = File('${dir.path}/moment.png');
    await photo.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    final bytes = await BookExporter.render(
      entries: [
        HistoryMoment(
          id: 'river',
          createdAt: DateTime.utc(2026, 3, 8),
          transcript: 'the river was high',
          imagePaths: [photo.path],
        ),
      ],
      start: DateTime.utc(2026, 1, 1),
      end: DateTime.utc(2026, 12, 31),
    );
    final raw = _pdfWords(bytes);
    expect(raw, contains('(river)'));
    expect(
      raw.contains('/Subtype /Image') || raw.contains('/Subtype/Image'),
      isTrue,
    );
    await dir.delete(recursive: true);
  });

  testWidgets('map plots a pin for a saved place', (tester) async {
    final pins = EntryMapClusters.cluster([
      HistoryMoment(
        id: 'home',
        createdAt: DateTime.utc(2026, 9, 1),
        transcript: 'home',
        place: 'Home',
        latitude: 51.5,
        longitude: -0.12,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: EntryMapView(pins: pins, onPin: (_) {}),
        ),
      ),
    );
    expect(find.byKey(const Key('entry_map_view')), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);
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
