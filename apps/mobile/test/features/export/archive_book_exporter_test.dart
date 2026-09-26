import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/features/export/archive_book_exporter.dart';
import 'package:archiveme_mobile/features/export/obsidian_archive_exporter.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_pdf_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

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
  return RegExp(r'\[\((.*?)\)\]TJ')
      .allMatches(buffer.toString())
      .map((match) => match.group(1)!)
      .join(' ');
}

int _pdfPageCount(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  return RegExp(r'/Type\s*/Page(?!s)').allMatches(raw).length;
}

void main() {
  test('prove enough PDF stays unsupported', () {
    expect(ProveEnoughPatternReportPdfExporter.isSupported, isFalse);
  });

  test('golden 3-page archive book quotes the entry', () async {
    final recordedAt = DateTime.utc(2026, 3, 8, 15);
    final pages = ArchiveBookExporter.plan(
      entries: [
        ArchiveBookEntry(
          id: 'one',
          recordedAt: recordedAt,
          transcript: 'I said this on that day.',
        ),
      ],
    );
    expect(pages, hasLength(3));
    expect(pages.map((page) => page.title), [
      'Thoughtprint archive',
      'Contents',
      'Entries',
    ]);

    final bytes = await ArchiveBookExporter.renderPages(pages);
    expect(_pdfPageCount(bytes), 3);
    final words = _pdfWords(bytes);
    expect(words, contains('Thoughtprint archive'));
    expect(words, contains('Contents'));
    expect(words, contains('I said this on that day.'));
    expect(words, contains('2026-03-08'));
  });

  test('pattern pages include only cited quotes', () {
    final pages = ArchiveBookExporter.plan(
      entries: [
        ArchiveBookEntry(
          id: 'one',
          recordedAt: DateTime.utc(2026, 3, 8),
          transcript: 'I said this on that day.',
        ),
      ],
      patterns: [
        const ArchiveBookPattern(title: 'Empty', citations: []),
        ArchiveBookPattern(
          title: 'Repeated words',
          citations: [
            ArchiveBookCitation(
              quote: 'I said this on that day.',
              recordedAt: DateTime.utc(2026, 3, 8),
            ),
          ],
        ),
      ],
    );
    expect(pages.last.title, 'Repeated words');
    expect(pages.last.lines.join(' '), contains('I said this on that day.'));
    expect(pages.any((page) => page.title == 'Empty'), isFalse);
  });

  test('obsidian zip has front matter and the audio file', () {
    final bytes = ObsidianArchiveExporter.buildZip(
      entries: [
        ArchiveBookEntry(
          id: 'one',
          recordedAt: DateTime.utc(2026, 3, 8),
          transcript: 'I said this on that day.',
          tags: const ['work'],
          audioFileName: 'clip.m4a',
          photoFileNames: const ['moment.jpg'],
        ),
      ],
      audioByFileName: {
        'clip.m4a': [1, 2, 3],
      },
      photosByFileName: {
        'moment.jpg': [4, 5],
      },
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final note = archive.files.singleWhere(
      (file) => file.name.endsWith('.md'),
    );
    final markdown = utf8.decode(note.content as List<int>);
    expect(markdown, contains('date: 2026-03-08'));
    expect(markdown, contains('tags:'));
    expect(markdown, contains('- work'));
    expect(markdown, contains('audio: clip.m4a'));
    expect(markdown, contains('![Audio](audio/clip.m4a)'));
    expect(markdown, contains('![[photos/moment.jpg]]'));
    expect(markdown, contains('I said this on that day.'));
    expect(markdown.contains('/var/'), isFalse);
    expect(
      archive.files.any((file) => file.name == 'audio/clip.m4a'),
      isTrue,
    );
    expect(
      archive.files.any((file) => file.name == 'photos/moment.jpg'),
      isTrue,
    );
  });

  test('1000 entries stream into pages', () async {
    final entries = [
      for (var i = 0; i < 1000; i++)
        ArchiveBookEntry(
          id: 'e$i',
          recordedAt: DateTime.utc(2020).add(Duration(days: i)),
          transcript: 'Entry $i',
        ),
    ];
    final started = Stopwatch()..start();
    final bytes = await ArchiveBookExporter.export(entries: entries);
    started.stop();
    expect(started.elapsed, lessThan(const Duration(seconds: 30)));
    expect(_pdfPageCount(bytes), greaterThan(100));
  });
}
