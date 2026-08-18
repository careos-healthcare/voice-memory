import 'package:archiveme_mobile/features/prove_enough/prove_enough_pattern_report_pdf_exporter.dart';

/// Export formats for selected entries.
///
/// Markdown is the supported path. PDF is offered only when a PDF
/// utility exists in this build (it currently does not — see
/// [ProveEnoughPatternReportPdfExporter.isSupported]).
enum ArchiveExportFormat {
  markdown,
  pdf;

  /// Stable analytics-safe id.
  String get id => switch (this) {
    ArchiveExportFormat.markdown => 'markdown',
    ArchiveExportFormat.pdf => 'pdf',
  };

  String get fileExtension => switch (this) {
    ArchiveExportFormat.markdown => 'md',
    ArchiveExportFormat.pdf => 'pdf',
  };

  bool get isSupported => switch (this) {
    ArchiveExportFormat.markdown => true,
    ArchiveExportFormat.pdf => ProveEnoughPatternReportPdfExporter.isSupported,
  };

  /// Formats available in this build.
  static List<ArchiveExportFormat> get supported =>
      values.where((f) => f.isSupported).toList();
}