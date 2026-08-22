import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_model.dart';

/// PDF export for prove_enough pattern reports.
///
/// PDF generation is not wired yet — Markdown export is the supported path.
/// When a PDF package is added, implement [exportToFile] with a light
/// ArchiveMe-branded layout and no VoiceMemory consumer copy.
class ProveEnoughPatternReportPdfExporter {
  const ProveEnoughPatternReportPdfExporter();

  /// Whether native PDF export is available in this build.
  static const bool isSupported = false;

  /// Writes a PDF when supported; otherwise returns null.
  Future<String?> exportToFile(ProveEnoughPatternReport report) async {
    if (!isSupported) return null;
    // TODO: generate light-theme ArchiveMe PDF with date range when pdf package is added.
    return null;
  }
}