import 'dart:typed_data';

import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a sanitized [ArchiveExportPayload] as a light ArchiveMe PDF.
///
/// Uses only the user-owned fields already present on the /export payload —
/// no audio paths, entry ids, or sync metadata. PDF generation is pure Dart.
abstract final class ExportPdfRenderer {
  ExportPdfRenderer._();

  static const fileName = 'archiveme_export.pdf';

  static const _ink = PdfColor.fromInt(0xFF172033);
  static const _muted = PdfColor.fromInt(0xFF667085);
  static const _rule = PdfColor.fromInt(0xFFE5E0D8);

  /// Builds PDF bytes for the share sheet.
  static Future<Uint8List> render(ArchiveExportPayload payload) async {
    final document = pw.Document(
      title: 'ArchiveMe journal export',
      author: 'ArchiveMe',
      creator: 'ArchiveMe',
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 48),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
        ),
        header: (context) => _header(payload, context),
        footer: (context) => _footer(context),
        build: (context) => [
          ..._intro(payload),
          if (payload.entries.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Text(
                'No reflections in this export.',
                style: const pw.TextStyle(color: _muted, fontSize: 11),
              ),
            )
          else
            for (var i = 0; i < payload.entries.length; i++)
              _entryBlock(payload.entries[i], isFirst: i == 0),
          ..._correctionNotes(payload.insightCorrectionNotes),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _header(ArchiveExportPayload payload, pw.Context context) {
    if (context.pageNumber > 1) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Text(
          'ArchiveMe - journal export',
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
      );
    }
    return pw.SizedBox();
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        '${context.pageNumber}',
        style: const pw.TextStyle(color: _muted, fontSize: 9),
      ),
    );
  }

  static List<pw.Widget> _intro(ArchiveExportPayload payload) {
    final count = payload.entries.length;
    final countLabel = count == 1 ? '1 reflection' : '$count reflections';
    return [
      pw.Text(
        'ArchiveMe',
        style: pw.TextStyle(
          color: _ink,
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Journal export',
        style: const pw.TextStyle(color: _ink, fontSize: 13),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        '${formatUserFacingDate(payload.exportedAt)} - $countLabel',
        style: const pw.TextStyle(color: _muted, fontSize: 10),
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        'Internal sync paths and audio file locations are not included.',
        style: const pw.TextStyle(color: _muted, fontSize: 9),
      ),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
        height: 1,
        color: _rule,
      ),
    ];
  }

  static pw.Widget _entryBlock(
    Map<String, dynamic> entry, {
    required bool isFirst,
  }) {
    final createdAt = DateTime.tryParse('${entry['createdAt'] ?? ''}');
    final dateLabel = createdAt == null
        ? 'Undated reflection'
        : formatUserFacingDate(createdAt);
    final transcript = _string(entry['transcript']);
    final duration = entry['durationSeconds'];
    final durationLabel = duration is int && duration > 0
        ? ' - ${duration}s'
        : '';
    final reflection = entry['reflection'];
    final reflectionMap = reflection is Map
        ? reflection.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};

    return pw.Padding(
      padding: pw.EdgeInsets.only(top: isFirst ? 8 : 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$dateLabel$durationLabel',
            style: pw.TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (transcript.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              transcript,
              style: const pw.TextStyle(color: _ink, fontSize: 11, height: 1.4),
            ),
          ],
          ..._reflectionLines(reflectionMap),
        ],
      ),
    );
  }

  static List<pw.Widget> _reflectionLines(Map<String, dynamic> reflection) {
    final widgets = <pw.Widget>[];
    final moodBits = <String>[];
    final mood = _string(reflection['mood']);
    if (mood.isNotEmpty) moodBits.add(mood);
    final intensity = reflection['emotionalIntensity'];
    if (intensity is int && intensity > 0) {
      moodBits.add('intensity $intensity/10');
    }
    final themes = reflection['recurringThemes'];
    if (themes is List) {
      final labels = themes
          .whereType<String>()
          .map((theme) => theme.trim())
          .where((theme) => theme.isNotEmpty)
          .toList();
      if (labels.isNotEmpty) moodBits.add(labels.join(', '));
    }
    if (moodBits.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Text(
          moodBits.join(' / '),
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
      );
    }

    for (final field in const [
      'concreteObservation',
      'exactLanguagePattern',
      'repeatedSignal',
    ]) {
      final value = _string(reflection[field]);
      if (value.isEmpty) continue;
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(
        pw.Text(
          value,
          style: const pw.TextStyle(color: _ink, fontSize: 10, height: 1.35),
        ),
      );
    }
    return widgets;
  }

  static List<pw.Widget> _correctionNotes(List<Map<String, String>> notes) {
    if (notes.isEmpty) return const [];
    final visible = notes
        .map((note) {
          final label = (note['label'] ?? '').trim();
          final body = (note['note'] ?? '').trim();
          if (body.isEmpty) return null;
          return (label.isEmpty ? 'Insight correction' : label, body);
        })
        .whereType<(String, String)>()
        .toList();
    if (visible.isEmpty) return const [];

    return [
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 28, bottom: 10),
        height: 1,
        color: _rule,
      ),
      pw.Text(
        'Insight corrections',
        style: pw.TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      for (final note in visible) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          note.$1,
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          note.$2,
          style: const pw.TextStyle(color: _ink, fontSize: 10, height: 1.35),
        ),
      ],
    ];
  }

  static String _string(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }
}
