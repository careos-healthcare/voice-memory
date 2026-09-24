import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One saved entry in an owned archive export.
class ArchiveBookEntry {
  const ArchiveBookEntry({
    required this.id,
    required this.recordedAt,
    required this.transcript,
    this.tags = const [],
    this.audioFileName,
  });

  final String id;
  final DateTime recordedAt;
  final String transcript;
  final List<String> tags;
  final String? audioFileName;
}

/// A pattern page may only repeat quotes that already appear in entries.
class ArchiveBookCitation {
  const ArchiveBookCitation({
    required this.quote,
    required this.recordedAt,
  });

  final String quote;
  final DateTime recordedAt;
}

class ArchiveBookPattern {
  const ArchiveBookPattern({
    required this.title,
    required this.citations,
  });

  final String title;
  final List<ArchiveBookCitation> citations;
}

/// One physical page. Built before drawing so a large archive is paged
/// in batches instead of one widget tree.
class ArchiveBookPage {
  const ArchiveBookPage({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

/// Chronological archive book: cover, contents, entries, cited pattern pages.
abstract final class ArchiveBookExporter {
  ArchiveBookExporter._();

  static const entriesPerPage = 8;

  static List<ArchiveBookEntry> inRange({
    required List<ArchiveBookEntry> entries,
    DateTime? start,
    DateTime? end,
  }) {
    final filtered = entries.where((entry) {
      final day = _dateOnly(entry.recordedAt.toLocal());
      if (start != null && day.isBefore(_dateOnly(start.toLocal()))) {
        return false;
      }
      if (end != null && day.isAfter(_dateOnly(end.toLocal()))) return false;
      return true;
    }).toList()..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return filtered;
  }

  static List<ArchiveBookPage> plan({
    required List<ArchiveBookEntry> entries,
    DateTime? start,
    DateTime? end,
    List<ArchiveBookPattern> patterns = const [],
    String title = 'Thoughtprint archive',
  }) {
    final selected = inRange(entries: entries, start: start, end: end);
    final cited = [
      for (final pattern in patterns)
        if (pattern.citations.any(
          (citation) => citation.quote.trim().isNotEmpty,
        ))
          pattern,
    ];
    final entryPageCount = selected.isEmpty
        ? 1
        : (selected.length / entriesPerPage).ceil();
    const patternStart = 3;
    final pages = <ArchiveBookPage>[
      ArchiveBookPage(
        title: title,
        lines: [
          title,
          'Your archive',
          if (start != null) 'From ${_stamp(start)}',
          if (end != null) 'Until ${_stamp(end)}',
          '${selected.length} entries',
        ],
      ),
      ArchiveBookPage(
        title: 'Contents',
        lines: [
          'Contents',
          'Entries, page 3',
          if (cited.isNotEmpty)
            'Patterns, page ${patternStart + entryPageCount - 1}',
        ],
      ),
    ];
    if (selected.isEmpty) {
      pages.add(
        const ArchiveBookPage(
          title: 'Entries',
          lines: ['Entries', 'No entries in this range.'],
        ),
      );
    } else {
      for (var i = 0; i < selected.length; i += entriesPerPage) {
        final slice = selected.skip(i).take(entriesPerPage);
        pages.add(
          ArchiveBookPage(
            title: 'Entries',
            lines: [
              'Entries',
              for (final entry in slice) ...[
                _stamp(entry.recordedAt),
                entry.transcript.trim(),
              ],
            ],
          ),
        );
      }
    }
    for (final pattern in cited) {
      pages.add(
        ArchiveBookPage(
          title: pattern.title,
          lines: [
            pattern.title,
            for (final citation in pattern.citations)
              if (citation.quote.trim().isNotEmpty)
                '${_stamp(citation.recordedAt)} ${citation.quote.trim()}',
          ],
        ),
      );
    }
    return pages;
  }

  /// Draws one page at a time so a large archive is not one widget list.
  static Future<Uint8List> renderPages(List<ArchiveBookPage> pages) async {
    final document = pw.Document(title: 'Thoughtprint archive');
    for (final page in pages) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in page.lines)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(line),
                ),
            ],
          ),
        ),
      );
    }
    return document.save();
  }

  static Future<Uint8List> export({
    required List<ArchiveBookEntry> entries,
    DateTime? start,
    DateTime? end,
    List<ArchiveBookPattern> patterns = const [],
  }) {
    return renderPages(
      plan(entries: entries, start: start, end: end, patterns: patterns),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _stamp(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
