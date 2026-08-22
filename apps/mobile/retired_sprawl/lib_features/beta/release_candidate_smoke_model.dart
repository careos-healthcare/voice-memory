import 'package:archiveme_mobile/features/beta/release_candidate_smoke_copy.dart';

enum ReleaseCandidateSmokeRowId {
  firstLaunchRecord,
  firstUseCapture,
  saveOneMoment,
  secondMomentGuidance,
  firstProofPath,
  coreValueFeedback,
  patternsArchive,
  evidenceTimeline,
  privateReportPreview,
  proRoute,
  restorePurchasesRoute,
  developerDiagnosticsLocked,
  microphonePermissionCopy,
  saveFailureCopy,
  privacySupportLink,
  resetArchiveControl,
  reportCopy,
}

enum ReleaseCandidateSmokeStatus {
  ready,
  checkManually,
  missing;

  String get label => switch (this) {
    ReleaseCandidateSmokeStatus.ready => ReleaseCandidateSmokeCopy.statusReady,
    ReleaseCandidateSmokeStatus.checkManually =>
      ReleaseCandidateSmokeCopy.statusCheckManually,
    ReleaseCandidateSmokeStatus.missing =>
      ReleaseCandidateSmokeCopy.statusMissing,
  };
}

class ReleaseCandidateSmokeRow {
  const ReleaseCandidateSmokeRow({
    required this.id,
    required this.label,
    required this.status,
  });

  final ReleaseCandidateSmokeRowId id;
  final String label;
  final ReleaseCandidateSmokeStatus status;
}

class ReleaseCandidateSmokeReport {
  const ReleaseCandidateSmokeReport({
    required this.title,
    required this.summary,
    required this.readyForTestFlight,
    required this.rows,
    required this.manualChecklistTitle,
    required this.manualChecklistSteps,
  });

  final String title;
  final String summary;
  final bool readyForTestFlight;
  final List<ReleaseCandidateSmokeRow> rows;
  final String manualChecklistTitle;
  final List<String> manualChecklistSteps;

  List<String> get visibleCopyBlocks => [
    title,
    summary,
    for (final row in rows) ...[row.label, row.status.label],
    manualChecklistTitle,
    ...manualChecklistSteps,
  ];
}