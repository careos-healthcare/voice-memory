import 'dart:typed_data';

import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class BookExporter {
  BookExporter._();

  static Future<Uint8List> render({
    required List<HistoryMoment> entries,
    required DateTime start,
    required DateTime end,
  }) async {
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

    final document = pw.Document();
    final months = <String, List<HistoryMoment>>{};
    for (final entry in selected) {
      final key =
          '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => []).add(entry);
    }
    if (months.isEmpty) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (context) => pw.Text('No moments in this range.'),
        ),
      );
    }
    for (final month in months.entries) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a5,
          build: (context) => [
            pw.Header(level: 0, text: month.key),
            for (final entry in month.value) ...[
              pw.Paragraph(text: entry.transcript),
              if ((entry.mood ?? '').isNotEmpty)
                pw.Text('Mood: ${entry.mood}'),
              if ((entry.place ?? '').isNotEmpty)
                pw.Text('Place: ${entry.place}'),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'thoughtprint://entry/${entry.id}',
                width: 48,
                height: 48,
              ),
              pw.SizedBox(height: 12),
            ],
          ],
        ),
      );
    }
    return document.save();
  }
}
