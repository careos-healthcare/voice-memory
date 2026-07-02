import 'beta_release_qa_copy.dart';

enum BetaReleaseQaRowId {
  betaMissionFlag,
  apiBaseUrlPresent,
  revenueCatKeyPresent,
  firstUsePromptAvailable,
  testerMissionAvailable,
  firstProofPathAvailable,
  returnCheckPathAvailable,
  evidenceTimelineAvailable,
  privateReportPreviewAvailable,
  proBridgeRouteAvailable,
  activationDropoffReviewAvailable,
}

enum BetaReleaseQaStatus {
  ready,
  missing,
  checkManually;

  String get label => switch (this) {
        BetaReleaseQaStatus.ready => BetaReleaseQaCopy.statusReady,
        BetaReleaseQaStatus.missing => BetaReleaseQaCopy.statusMissing,
        BetaReleaseQaStatus.checkManually =>
          BetaReleaseQaCopy.statusCheckManually,
      };
}

class BetaReleaseQaRow {
  const BetaReleaseQaRow({
    required this.id,
    required this.label,
    required this.status,
    this.detail,
  });

  final BetaReleaseQaRowId id;
  final String label;
  final BetaReleaseQaStatus status;
  final String? detail;
}

class BetaReleaseQaReport {
  const BetaReleaseQaReport({
    required this.title,
    required this.summary,
    required this.readyForTesterBuild,
    required this.rows,
    required this.manualChecklistTitle,
    required this.manualChecklistSteps,
  });

  final String title;
  final String summary;
  final bool readyForTesterBuild;
  final List<BetaReleaseQaRow> rows;
  final String manualChecklistTitle;
  final List<String> manualChecklistSteps;

  List<String> get visibleCopyBlocks => [
        title,
        summary,
        for (final row in rows) ...[
          row.label,
          row.status.label,
          if (row.detail != null) row.detail!,
        ],
        manualChecklistTitle,
        ...manualChecklistSteps,
      ];
}
