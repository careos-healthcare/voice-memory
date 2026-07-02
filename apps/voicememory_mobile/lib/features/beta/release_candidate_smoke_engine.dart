import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../config/developer_settings_gate.dart';
import '../../record/record_screen_framing_copy.dart';
import '../../router/developer_route_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../early_archive/early_evidence_timeline_copy.dart';
import '../early_archive/first_proof_moment_copy.dart';
import '../early_archive/private_archive_report_copy.dart';
import '../onboarding/archive_journey_copy.dart';
import '../../billing/restore_purchases_copy.dart';
import 'archive_beta_mission_gate.dart';
import 'core_value_feedback_copy.dart';
import 'release_candidate_smoke_copy.dart';
import 'release_candidate_smoke_model.dart';
import 'tester_mission_copy.dart';

/// Read-only release candidate smoke checks — no network, purchases, or restores.
abstract final class ReleaseCandidateSmokeEngine {
  ReleaseCandidateSmokeEngine._();

  @visibleForTesting
  static bool? developerDiagnosticsLockedOverride;

  static ReleaseCandidateSmokeReport build() {
    final rows = <ReleaseCandidateSmokeRow>[
      _firstLaunchRecordRow(),
      _firstUseCaptureRow(),
      _saveOneMomentRow(),
      _secondMomentGuidanceRow(),
      _firstProofPathRow(),
      _coreValueFeedbackRow(),
      _patternsArchiveRow(),
      _evidenceTimelineRow(),
      _privateReportPreviewRow(),
      _proRouteRow(),
      _restorePurchasesRouteRow(),
      _developerDiagnosticsLockedRow(),
    ];

    final readyForTestFlight = rows.every(
      (row) => row.status == ReleaseCandidateSmokeStatus.ready,
    );

    return ReleaseCandidateSmokeReport(
      title: ReleaseCandidateSmokeCopy.sectionTitle,
      summary: readyForTestFlight
          ? ReleaseCandidateSmokeCopy.summaryReady
          : ReleaseCandidateSmokeCopy.summaryNeedsAttention,
      readyForTestFlight: readyForTestFlight,
      rows: rows,
      manualChecklistTitle: ReleaseCandidateSmokeCopy.manualChecklistTitle,
      manualChecklistSteps: ReleaseCandidateSmokeCopy.manualChecklistSteps,
    );
  }

  static ReleaseCandidateSmokeRow _firstLaunchRecordRow() {
    final available = ReleaseCandidateSmokeCopy.recordRoute == '/record';
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.firstLaunchRecord,
      label: ReleaseCandidateSmokeCopy.rowFirstLaunchRecord,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _firstUseCaptureRow() {
    final available = RecordFirstUsePromptCopy.title.isNotEmpty &&
        RecordFirstUsePromptCopy.body.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.firstUseCapture,
      label: ReleaseCandidateSmokeCopy.rowFirstUseCapture,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _saveOneMomentRow() {
    final available = VisibleArchiveProofCopy.firstUseCaptureCta.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.saveOneMoment,
      label: ReleaseCandidateSmokeCopy.rowSaveOneMoment,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _secondMomentGuidanceRow() {
    final available = (ArchiveJourneyCopy.compactStep2Title.isNotEmpty &&
            ArchiveJourneyCopy.compactHelper.isNotEmpty) ||
        (TesterMissionCopy.entry1Body.isNotEmpty &&
            TesterMissionCopy.entry1StepLabel.isNotEmpty);
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.secondMomentGuidance,
      label: ReleaseCandidateSmokeCopy.rowSecondMomentGuidance,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _firstProofPathRow() {
    final available = FirstProofMomentCopy.title.isNotEmpty &&
        FirstProofMomentCopy.whyLine.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.firstProofPath,
      label: ReleaseCandidateSmokeCopy.rowFirstProofPath,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _coreValueFeedbackRow() {
    final available = ArchiveBetaMissionGate.isEnabled &&
        CoreValueFeedbackCopy.question.isNotEmpty &&
        CoreValueFeedbackCopy.title.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.coreValueFeedback,
      label: ReleaseCandidateSmokeCopy.rowCoreValueFeedback,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _patternsArchiveRow() {
    final available =
        ReleaseCandidateSmokeCopy.patternsRoute == DeveloperRouteGuard.patternsHome;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.patternsArchive,
      label: ReleaseCandidateSmokeCopy.rowPatternsArchive,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _evidenceTimelineRow() {
    final available = EarlyEvidenceTimelineCopy.title.isNotEmpty &&
        EarlyEvidenceTimelineCopy.repeatConfirmedTitle.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.evidenceTimeline,
      label: ReleaseCandidateSmokeCopy.rowEvidenceTimeline,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _privateReportPreviewRow() {
    final available = PrivateArchiveReportCopy.previewTitle.isNotEmpty &&
        PrivateArchiveReportCopy.previewBody.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.privateReportPreview,
      label: ReleaseCandidateSmokeCopy.rowPrivateReportPreview,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _proRouteRow() {
    final available = ReleaseCandidateSmokeCopy.proRoute.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.proRoute,
      label: ReleaseCandidateSmokeCopy.rowProRoute,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _restorePurchasesRouteRow() {
    final available =
        ReleaseCandidateSmokeCopy.restorePurchasesRoute.isNotEmpty &&
            RestorePurchasesCopy.restorePurchases.isNotEmpty;
    return ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.restorePurchasesRoute,
      label: ReleaseCandidateSmokeCopy.rowRestorePurchasesRoute,
      status: available
          ? ReleaseCandidateSmokeStatus.ready
          : ReleaseCandidateSmokeStatus.missing,
    );
  }

  static ReleaseCandidateSmokeRow _developerDiagnosticsLockedRow() {
    if (developerDiagnosticsLockedOverride != null) {
      return ReleaseCandidateSmokeRow(
        id: ReleaseCandidateSmokeRowId.developerDiagnosticsLocked,
        label: ReleaseCandidateSmokeCopy.rowDeveloperDiagnosticsLocked,
        status: developerDiagnosticsLockedOverride!
            ? ReleaseCandidateSmokeStatus.ready
            : ReleaseCandidateSmokeStatus.missing,
      );
    }

    if (DeveloperSettingsGate.exposeDeveloperSettingsInDebug) {
      return const ReleaseCandidateSmokeRow(
        id: ReleaseCandidateSmokeRowId.developerDiagnosticsLocked,
        label: ReleaseCandidateSmokeCopy.rowDeveloperDiagnosticsLocked,
        status: ReleaseCandidateSmokeStatus.missing,
      );
    }

    final guarded = DeveloperRouteGuard.developerOnlyPaths
        .contains(ReleaseCandidateSmokeCopy.developerDiagnosticsRoute);
    if (!guarded) {
      return const ReleaseCandidateSmokeRow(
        id: ReleaseCandidateSmokeRowId.developerDiagnosticsLocked,
        label: ReleaseCandidateSmokeCopy.rowDeveloperDiagnosticsLocked,
        status: ReleaseCandidateSmokeStatus.missing,
      );
    }

    if (kReleaseMode && !AppConfig.isDebugBuild) {
      return const ReleaseCandidateSmokeRow(
        id: ReleaseCandidateSmokeRowId.developerDiagnosticsLocked,
        label: ReleaseCandidateSmokeCopy.rowDeveloperDiagnosticsLocked,
        status: ReleaseCandidateSmokeStatus.ready,
      );
    }

    return const ReleaseCandidateSmokeRow(
      id: ReleaseCandidateSmokeRowId.developerDiagnosticsLocked,
      label: ReleaseCandidateSmokeCopy.rowDeveloperDiagnosticsLocked,
      status: ReleaseCandidateSmokeStatus.checkManually,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    developerDiagnosticsLockedOverride = null;
  }
}
