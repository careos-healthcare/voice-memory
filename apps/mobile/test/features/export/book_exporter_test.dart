import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/export/printed_book_quote.dart';
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

  test(
    'each month is listed and a then and now page sits between them',
    () async {
      final bytes = await BookExporter.build(
        _book([
          _entry(8, transcript: 'the river was high'),
          const JournalBookEntry(
            dateString: '2026-04-02',
            transcript: 'the hill was quiet',
            location: 'ridge',
          ),
        ]),
      );
      final words = _pdfWords(bytes);
      expect(words, contains("Ada's Journal - 2026"));
      expect(words, contains('Contents'));
      expect(words, contains('March 2026'));
      expect(words, contains('April 2026'));
      expect(words, contains('Then'));
      expect(words, contains('Now'));
      expect(words, contains('the river was high'));
      expect(words, contains('the hill was quiet'));
      expect(_pageCount(bytes), 5);
    },
  );

  test('the quote uses the rendered page count and cover width', () async {
    final bytes = await BookExporter.build(
      _book([_entry(8, transcript: 'the river was high')]),
    );
    final pages = _pageCount(bytes);
    final quote = PrintedBookQuote.forPages(
      pageCount: pages,
      size: BookPageSize.a5,
    );
    expect(quote.pageCount, pages);
    expect(
      quote.coverWidthInches,
      LuluCover.widthInches(pageCount: pages, trimWidthInches: 5.83),
    );
    expect(LuluCover.widthInches(pageCount: 100, trimWidthInches: 6), 12.4752);
    expect(BookExporter.marginsFor(BookPageSize.a5).left, greaterThanOrEqualTo(36));
    expect(latin1.decode(bytes, allowInvalid: true).contains('thoughtprint://'), isFalse);
  });

  test('a large book reports progress', () async {
    final updates = <int>[];
    final dir = await Directory.systemTemp.createTemp('book_photos_');
    final photo = File('${dir.path}/dot.jpg');
    await photo.writeAsBytes(base64Decode(_tinyJpeg));
    final entries = [
      for (var index = 0; index < 1000; index++)
        JournalBookEntry(
          dateString:
              '2024-${((index % 12) + 1).toString().padLeft(2, '0')}-01',
          transcript: 'moment $index',
          imagePaths: index < 200 ? [photo.path] : const [],
        ),
    ];
    final started = Stopwatch()..start();
    final bytes = await BookExporter.build(
      JournalBook(title: 'Year', author: '', entries: entries),
      onProgress: (done, total) => updates.add(done),
    );
    started.stop();
    expect(started.elapsed, lessThan(const Duration(seconds: 60)));
    expect(bytes, isNotEmpty);
    expect(updates, isNotEmpty);
    expect(updates.last, greaterThan(0));
  });
}

const _tinyJpeg =
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

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
              map[int.parse(
                raw.substring(index, index + 4),
                radix: 16,
              )];
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
