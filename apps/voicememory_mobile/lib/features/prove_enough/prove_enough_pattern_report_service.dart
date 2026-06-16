import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'prove_enough_pattern_report_coordinator.dart';
import 'prove_enough_pattern_report_exporter.dart';
import 'prove_enough_pattern_report_model.dart';
import 'prove_enough_pattern_report_pdf_exporter.dart';

/// Shares a prove_enough pattern report when the user taps export.
abstract class ProveEnoughPatternReportService {
  ProveEnoughPatternReportService._();

  static const _exporter = ProveEnoughPatternReportExporter();
  static const _pdfExporter = ProveEnoughPatternReportPdfExporter();

  static Future<ProveEnoughPatternReport> loadReport({DateTime? now}) {
    return ProveEnoughPatternReportCoordinator.load(now: now);
  }

  static String markdownFor(ProveEnoughPatternReport report) {
    return _exporter.toMarkdown(report);
  }

  static Future<bool> shareReport(ProveEnoughPatternReport report) async {
    final markdown = markdownFor(report);
    final dir = await getTemporaryDirectory();
    final markdownPath =
        '${dir.path}/prove_enough_pattern_report_${report.generatedAt.millisecondsSinceEpoch}.md';
    await File(markdownPath).writeAsString(markdown);

    final files = <XFile>[XFile(markdownPath)];
    if (ProveEnoughPatternReportPdfExporter.isSupported) {
      final pdfPath = await _pdfExporter.exportToFile(report);
      if (pdfPath != null) {
        files.add(XFile(pdfPath));
      }
    }

    await Share.shareXFiles(
      files,
      subject: ProveEnoughPatternReport.reportTitle,
    );
    return true;
  }
}
