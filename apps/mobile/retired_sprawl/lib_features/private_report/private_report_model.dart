import 'package:archiveme_mobile/features/early_archive/private_archive_report_model.dart';

/// Built private report with safe metadata for analytics.
class PrivateReportBuildResult {
  const PrivateReportBuildResult({
    required this.report,
    required this.hasChange,
    required this.hasHelped,
  });

  final PrivateArchiveReport report;
  final bool hasChange;
  final bool hasHelped;
}