import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/theme/pdf_fonts.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum BookPageSize { a5, usTrade }

class JournalBookEntry {
  const JournalBookEntry({
    required this.dateString,
    required this.transcript,
    this.mood,
    this.location,
    /// Future option. Hosted audio conflicts with a local-first book, so
    /// [JournalBook.includeAudioQr] stays off and this is not drawn.
    this.audioQrUrl,
    this.imagePaths = const [],
  });

  final String dateString;
  final String transcript;
  final String? mood;
  final String? location;

  /// Not used unless the book opts in. Left for a later hosted-audio book.
  final String? audioQrUrl;
  final List<String> imagePaths;
}

class JournalBook {
  const JournalBook({
    required this.title,
    required this.entries,
    this.subtitle = 'A printed journal',
    this.author = 'Thoughtprint',
    this.pageSize = BookPageSize.a5,
    this.includeThenAndNow = true,
    this.includeAudioQr = false,
  });

  final String title;
  final String subtitle;

  /// Empty when the reader leaves their name off the cover.
  final String author;
  final List<JournalBookEntry> entries;
  final BookPageSize pageSize;
  final bool includeThenAndNow;

  /// Off by default. A playable code needs hosted audio.
  final bool includeAudioQr;
}

class _Chapter {
  _Chapter({required this.title, required this.entries});

  final String title;
  final List<JournalBookEntry> entries;
}

class _PullQuote {
  const _PullQuote({required this.thenQuote, required this.nowQuote});

  final String thenQuote;
  final String nowQuote;
}

abstract final class BookExporter {
  BookExporter._();

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static Future<Uint8List> build(
    JournalBook book, {
    void Function(int done, int total)? onProgress,
  }) async {
    final font = await PdfFonts.newsreader();
    final italic = await PdfFonts.newsreaderItalic();
    final label = await PdfFonts.inter(font);
    final theme = pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: italic,
      boldItalic: italic,
    );
    final chapters = _chapters(book.entries);
    final quotes = book.includeThenAndNow
        ? _pullQuotes(chapters)
        : const <_PullQuote?>[];
    final plan = _plan(chapters: chapters, quotes: quotes);
    final document = pw.Document(theme: theme);
    final steps = 2 + chapters.length + quotes.whereType<_PullQuote>().length;
    var done = 0;
    void tick() {
      done += 1;
      onProgress?.call(done, steps);
    }

    document.addPage(_cover(book, font, italic));
    tick();
    document.addPage(_contents(book, chapters, plan.starts, font));
    tick();
    for (var index = 0; index < plan.blanksBeforeFirst; index++) {
      document.addPage(_blank(book));
    }
    for (var index = 0; index < chapters.length; index++) {
      final photos = await _photos(chapters[index].entries);
      document.addPage(
        _chapterPages(
          book: book,
          chapter: chapters[index],
          startPage: plan.starts[index],
          theme: theme,
          font: font,
          label: label,
          photos: photos,
        ),
      );
      tick();
      if (!book.includeThenAndNow || index >= quotes.length) continue;
      final quote = quotes[index];
      for (var blank = 0; blank < plan.blanksBeforeQuote[index]; blank++) {
        document.addPage(_blank(book));
      }
      if (quote != null) {
        document.addPage(_quotePage(book, quote, italic, font));
        tick();
      }
      for (var blank = 0; blank < plan.blanksAfterQuote[index]; blank++) {
        document.addPage(_blank(book));
      }
    }
    onProgress?.call(steps, steps);
    return document.save();
  }

  static Future<File> save(JournalBook book, {required String path}) async {
    final file = File(path);
    await file.writeAsBytes(await build(book));
    return file;
  }

  static Future<File> generatePdfBook({
    required List<JournalBookEntry> entries,
    required String path,
    String title = 'Thoughtprint',
  }) {
    return save(
      JournalBook(title: title, entries: entries),
      path: path,
    );
  }

  static Future<Uint8List> render({
    required List<HistoryMoment> entries,
    required DateTime start,
    required DateTime end,
    Map<String, String> audioQrUrls = const {},
    bool includeAudioQr = false,
    BookPageSize pageSize = BookPageSize.a5,
    bool includeThenAndNow = true,
    String title = 'Thoughtprint',
    String author = 'Thoughtprint',
    void Function(int done, int total)? onProgress,
  }) {
    final selected = entries.where((entry) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      final from = DateTime(start.year, start.month, start.day);
      final to = DateTime(end.year, end.month, end.day);
      return !day.isBefore(from) && !day.isAfter(to);
    }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = selected.isEmpty ? start : selected.first.createdAt;
    final last = selected.isEmpty ? end : selected.last.createdAt;
    return build(
      JournalBook(
        title: title,
        subtitle: '${_dayLabel(first)} – ${_dayLabel(last)}',
        author: author,
        pageSize: pageSize,
        includeThenAndNow: includeThenAndNow,
        includeAudioQr: includeAudioQr,
        entries: [
          for (final entry in selected)
            JournalBookEntry(
              dateString: _dayLabel(entry.createdAt),
              transcript: entry.transcript,
              mood: entry.mood,
              location: entry.place,
              audioQrUrl: includeAudioQr ? audioQrUrls[entry.id] : null,
              imagePaths: entry.imagePaths,
            ),
        ],
      ),
      onProgress: onProgress,
    );
  }

  static Future<Map<String, Uint8List>> _photos(
    List<JournalBookEntry> entries,
  ) async {
    final photos = <String, Uint8List>{};
    for (final entry in entries) {
      for (final path in entry.imagePaths) {
        final file = File(path);
        if (await file.exists()) photos[path] = await file.readAsBytes();
      }
    }
    return photos;
  }

  static List<_Chapter> _chapters(List<JournalBookEntry> entries) {
    final groups = <String, List<JournalBookEntry>>{};
    for (final entry in entries) {
      final day = _parseDay(entry.dateString);
      final key = day == null
          ? 'Moments'
          : '${_months[day.month - 1]} ${day.year}';
      groups.putIfAbsent(key, () => []).add(entry);
    }
    return [
      for (final group in groups.entries)
        _Chapter(title: group.key, entries: group.value),
    ];
  }

  static List<_PullQuote?> _pullQuotes(List<_Chapter> chapters) {
    final quotes = <_PullQuote?>[];
    for (var index = 0; index < chapters.length - 1; index++) {
      final earlier = chapters[index].entries.last.transcript.trim();
      final current = chapters[index + 1].entries.first.transcript.trim();
      if (earlier.isEmpty || current.isEmpty) {
        quotes.add(null);
        continue;
      }
      quotes.add(
        _PullQuote(thenQuote: _snippet(earlier), nowQuote: _snippet(current)),
      );
    }
    return quotes;
  }

  static PdfPageFormat formatFor(BookPageSize size) {
    if (size == BookPageSize.usTrade) {
      return const PdfPageFormat(6 * PdfPageFormat.inch, 9 * PdfPageFormat.inch);
    }
    return PdfPageFormat.a5;
  }

  /// Inside edge is at least half an inch so a home printer can bind the sheet.
  static pw.EdgeInsets marginsFor(BookPageSize size) {
    final page = formatFor(size);
    final gutter = 0.5 * PdfPageFormat.inch;
    final vertical = gutter < page.height / 4 ? 40.0 : gutter;
    return pw.EdgeInsets.fromLTRB(gutter, vertical, gutter, vertical);
  }

  static _Plan _plan({
    required List<_Chapter> chapters,
    required List<_PullQuote?> quotes,
  }) {
    final starts = <int>[];
    final blanksBeforeQuote = <int>[];
    final blanksAfterQuote = <int>[];
    var next = 3;
    var blanksBeforeFirst = 0;
    if (next.isEven) {
      blanksBeforeFirst = 1;
      next += 1;
    }
    for (var index = 0; index < chapters.length; index++) {
      starts.add(next);
      final count = _estimatedPages(chapters[index]);
      next += count;
      if (index >= quotes.length) continue;
      final quote = quotes[index];
      if (quote == null) {
        final after = next.isEven ? 1 : 0;
        blanksBeforeQuote.add(0);
        blanksAfterQuote.add(after);
        next += after;
        continue;
      }
      blanksBeforeQuote.add(0);
      next += 1;
      final after = next.isEven ? 1 : 0;
      blanksAfterQuote.add(after);
      next += after;
    }
    return _Plan(
      starts: starts,
      blanksBeforeFirst: blanksBeforeFirst,
      blanksBeforeQuote: blanksBeforeQuote,
      blanksAfterQuote: blanksAfterQuote,
    );
  }

  /// One text page holds about 1,800 characters. A photo takes a page of its own.
  static int _estimatedPages(_Chapter chapter) {
    var characters = 0;
    var photos = 0;
    for (final entry in chapter.entries) {
      characters += entry.transcript.length;
      photos += entry.imagePaths.length;
    }
    final textPages = characters <= 1800 ? 1 : (characters / 1800).ceil();
    return textPages + photos;
  }

  static pw.Page _cover(JournalBook book, pw.Font font, pw.Font italic) {
    final year = _coverYear(book);
    final name = book.author.trim();
    final range = book.entries.isEmpty
        ? book.subtitle
        : '${book.entries.first.dateString} – ${book.entries.last.dateString}';
    final heading = name.isEmpty ? book.title : "$name's Journal - $year";
    return pw.Page(
      pageFormat: formatFor(book.pageSize),
      theme: pw.ThemeData.withFont(base: font, italic: italic),
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              heading,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 28),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              range,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: italic, fontSize: 12),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              book.title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Page _contents(
    JournalBook book,
    List<_Chapter> chapters,
    List<int> starts,
    pw.Font font,
  ) {
    return pw.Page(
      pageFormat: formatFor(book.pageSize),
      margin: marginsFor(book.pageSize),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'Contents',
            style: pw.TextStyle(font: font, fontSize: 22),
          ),
          pw.SizedBox(height: 18),
          if (chapters.isEmpty)
            pw.Text(
              'No moments in this range.',
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          for (var index = 0; index < chapters.length; index++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    chapters[index].title,
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    '${starts[index]}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Page _blank(JournalBook book) {
    return pw.Page(
      pageFormat: formatFor(book.pageSize),
      build: (context) => pw.SizedBox(),
    );
  }

  static pw.MultiPage _chapterPages({
    required JournalBook book,
    required _Chapter chapter,
    required int startPage,
    required pw.ThemeData theme,
    required pw.Font font,
    required pw.Font label,
    required Map<String, Uint8List> photos,
  }) {
    return pw.MultiPage(
      pageFormat: formatFor(book.pageSize),
      theme: theme,
      maxPages: 400,
      margin: marginsFor(book.pageSize),
      footer: (context) => pw.Container(
        height: 24,
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${startPage + context.pageNumber - 1}',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
      ),
      build: (context) => [
        pw.Text(
          chapter.title,
          style: pw.TextStyle(font: font, fontSize: 26),
        ),
        pw.SizedBox(height: 18),
        for (final entry in chapter.entries) ...[
          pw.Text(
            _metaLine(entry),
            style: pw.TextStyle(font: label, fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            entry.transcript,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
          for (final path in entry.imagePaths)
            if (photos[path] != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Image(
                  pw.MemoryImage(photos[path]!),
                  fit: pw.BoxFit.fitWidth,
                ),
              ),
          if (book.includeAudioQr && (entry.audioQrUrl ?? '').trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: entry.audioQrUrl!.trim(),
                width: 48,
                height: 48,
              ),
            ),
          pw.SizedBox(height: 18),
        ],
      ],
    );
  }

  static String _metaLine(JournalBookEntry entry) {
    final parts = [
      entry.dateString.trim(),
      (entry.location ?? '').trim(),
      (entry.mood ?? '').trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(' · ');
  }

  static pw.Page _quotePage(
    JournalBook book,
    _PullQuote quote,
    pw.Font italic,
    pw.Font font,
  ) {
    return pw.Page(
      pageFormat: formatFor(book.pageSize),
      margin: marginsFor(book.pageSize),
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Then', style: pw.TextStyle(font: font, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Text(
              quote.thenQuote,
              style: pw.TextStyle(font: italic, fontSize: 16, lineSpacing: 4),
            ),
            pw.SizedBox(height: 28),
            pw.Text('Now', style: pw.TextStyle(font: font, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Text(
              quote.nowQuote,
              style: pw.TextStyle(font: italic, fontSize: 16, lineSpacing: 4),
            ),
          ],
        ),
      ),
    );
  }

  static String _snippet(String transcript) {
    final compact = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) return compact;
    return '${compact.substring(0, 177).trim()}…';
  }

  static DateTime? _parseDay(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static int _coverYear(JournalBook book) {
    for (final entry in book.entries) {
      final day = _parseDay(entry.dateString);
      if (day != null) return day.year;
    }
    return DateTime.now().year;
  }

  static String _dayLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _Plan {
  const _Plan({
    required this.starts,
    required this.blanksBeforeFirst,
    required this.blanksBeforeQuote,
    required this.blanksAfterQuote,
  });

  final List<int> starts;
  final int blanksBeforeFirst;
  final List<int> blanksBeforeQuote;
  final List<int> blanksAfterQuote;
}
