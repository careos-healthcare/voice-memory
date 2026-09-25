import 'dart:io';

import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

JournalBook _book(List<JournalBookEntry> entries) {
  return JournalBook(
    title: 'Year in words',
    subtitle: 'Printed from the phone',
    author: 'Ada',
    entries: entries,
  );
}

JournalBookEntry _entry(int day, {String transcript = 'a quiet walk'}) {
  return JournalBookEntry(
    dateString: '2026-03-${day.toString().padLeft(2, '0')}',
    transcript: transcript,
    mood: 'calm',
    location: 'bridge',
    audioQrUrl: 'thoughtprint://entry/$day',
  );
}

int _pageCount(List<int> bytes) {
  final raw = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page(?!s)').allMatches(raw).length;
}

void main() {
  test('an empty journal still writes a cover', () async {
    final dir = await Directory.systemTemp.createTemp('journal_book_');
    final file = await BookExporter.save(
      _book(const []),
      path: '${dir.path}/empty.pdf',
    );
    final bytes = await file.readAsBytes();
    expect(bytes, isNotEmpty);
    expect(file.existsSync(), isTrue);
    expect(_pageCount(bytes), greaterThanOrEqualTo(1));
  });

  test('one entry writes a non-empty file', () async {
    final dir = await Directory.systemTemp.createTemp('journal_book_');
    final file = await BookExporter.save(
      _book([_entry(8, transcript: 'the river was high')]),
      path: '${dir.path}/one.pdf',
    );
    final bytes = await file.readAsBytes();
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(500));
  });

  test('many entries span more than one page', () async {
    final entries = [
      for (var day = 1; day <= 24; day++)
        _entry(day, transcript: 'moment $day. ' * 40),
    ];
    final bytes = await BookExporter.build(_book(entries));
    expect(bytes, isNotEmpty);
    expect(_pageCount(bytes), greaterThan(1));
  });
}
