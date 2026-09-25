import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class JournalBookEntry {
  const JournalBookEntry({
    required this.dateString,
    required this.transcript,
    this.mood,
    this.location,
    this.audioQrUrl,
  });

  final String dateString;
  final String transcript;
  final String? mood;
  final String? location;
  final String? audioQrUrl;
}

class JournalBook {
  const JournalBook({
    required this.title,
    required this.entries,
    this.subtitle = 'A printed journal',
    this.author = 'Thoughtprint',
  });

  final String title;
  final String subtitle;
  final String author;
  final List<JournalBookEntry> entries;
}

abstract final class BookExporter {
  BookExporter._();

  static Future<Uint8List> build(JournalBook book) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(book.title, style: pw.TextStyle(fontSize: 28)),
              pw.SizedBox(height: 12),
              pw.Text(book.subtitle, style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 24),
              pw.Text(book.author),
            ],
          ),
        ),
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('${context.pageNumber}'),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('${context.pageNumber} / ${context.pagesCount}'),
        ),
        build: (context) {
          if (book.entries.isEmpty) {
            return [pw.Text('No moments in this range.')];
          }
          return [
            for (final entry in book.entries) ...[
              pw.Header(level: 1, text: entry.dateString),
              if ((entry.mood ?? '').trim().isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(8),
                    color: PdfColors.blue100,
                  ),
                  child: pw.Text(entry.mood!.trim()),
                ),
              pw.SizedBox(height: 8),
              pw.Text(entry.transcript, style: const pw.TextStyle(lineSpacing: 4)),
              if ((entry.location ?? '').trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(entry.location!.trim()),
                ),
              if ((entry.audioQrUrl ?? '').trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: entry.audioQrUrl!.trim(),
                    width: 48,
                    height: 48,
                  ),
                ),
              pw.SizedBox(height: 16),
            ],
          ];
        },
      ),
    );
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
    return save(JournalBook(title: title, entries: entries), path: path);
  }

  static Future<Uint8List> render({
    required List<HistoryMoment> entries,
    required DateTime start,
    required DateTime end,
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
    return build(
      JournalBook(
        title: 'Thoughtprint',
        entries: [
          for (final entry in selected)
            JournalBookEntry(
              dateString:
                  '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}',
              transcript: entry.transcript,
              mood: entry.mood,
              location: entry.place,
              audioQrUrl: 'thoughtprint://entry/${entry.id}',
            ),
        ],
      ),
    );
  }
}
