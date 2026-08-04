import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../record/record_screen_framing_copy.dart';
import '../activation/activation_dropoff_review_engine.dart';
import '../activation/activation_dropoff_review_model.dart';
import '../debug/archive_beta_debug_gate.dart';
import 'archive_beta_mission_gate.dart';
import 'beta_release_qa_copy.dart';
import 'beta_release_qa_model.dart';
import 'core_value_feedback_store.dart';
import 'tester_mission_copy.dart';

/// Read-only beta build readiness checks — no network, purchases, or restores.
abstract final class BetaReleaseQaEngine {
  BetaReleaseQaEngine._();

  @visibleForTesting
  static bool? apiBaseUrlPresentOverride;

  @visibleForTesting
  static bool? revenueCatKeyPresentOverride;

  @visibleForTesting
  static bool? proBridgeRouteAvailableOverride;

  static BetaReleaseQaReport build() {
    final rows = <BetaReleaseQaRow>[
      _betaMissionRow(),
      _apiBaseUrlRow(),
      _revenueCatKeyRow(),
      _firstUsePromptRow(),
      _testerMissionRow(),
      _firstProofPathRow(),
      _returnCheckPathRow(),
      _evidenceTimelineRow(),
      _privateReportPreviewRow(),
      _proBridgeRouteRow(),
      _activationDropoffReviewRow(),
    ];

    final readyForTesterBuild = rows.every(
      (row) => row.status == BetaReleaseQaStatus.ready,
    );

    return BetaReleaseQaReport(
      title: BetaReleaseQaCopy.sectionTitle,
      summary: readyForTesterBuild
          ? BetaReleaseQaCopy.summaryReady
          : BetaReleaseQaCopy.summaryNeedsAttention,
      readyForTesterBuild: readyForTesterBuild,
      rows: rows,
      manualChecklistTitle: BetaReleaseQaCopy.manualChecklistTitle,
      manualChecklistSteps: BetaReleaseQaCopy.manualChecklistSteps,
      coreValueQuestionTitle: BetaReleaseQaCopy.coreValueQuestionTitle,
      coreValueQuestion: BetaReleaseQaCopy.coreValueQuestion,
      coreValueFeedbackLabel: BetaReleaseQaCopy.coreValueFeedbackLabel,
      coreValueFeedbackAnswer: CoreValueFeedbackStore.cached.diagnosticsSummary,
    );
  }

  static BetaReleaseQaRow _betaMissionRow() {
    final enabled = ArchiveBetaMissionGate.isEnabled;
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.betaMissionFlag,
      label: BetaReleaseQaCopy.rowBetaMissionFlag,
      status: enabled ? BetaReleaseQaStatus.ready : BetaReleaseQaStatus.missing,
      detail: enabled
          ? BetaReleaseQaCopy.detailEnabled
          : BetaReleaseQaCopy.detailOff,
    );
  }

  static BetaReleaseQaRow _apiBaseUrlRow() {
    final present = apiBaseUrlPresentOverride ?? _apiBaseUrlPresent();
    final status = present
        ? (kReleaseMode && AppConfig.looksLikeLocalhost
              ? BetaReleaseQaStatus.checkManually
              : BetaReleaseQaStatus.ready)
        : BetaReleaseQaStatus.missing;
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.apiBaseUrlPresent,
      label: BetaReleaseQaCopy.rowApiBaseUrlPresent,
      status: status,
      detail: present
          ? BetaReleaseQaCopy.detailSet
          : BetaReleaseQaCopy.detailMissing,
    );
  }

  static BetaReleaseQaRow _revenueCatKeyRow() {
    final present = revenueCatKeyPresentOverride ?? _revenueCatKeyPresent();
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.revenueCatKeyPresent,
      label: BetaReleaseQaCopy.rowRevenueCatKeyPresent,
      status: present
          ? BetaReleaseQaStatus.ready
          : (kReleaseMode
                ? BetaReleaseQaStatus.checkManually
                : BetaReleaseQaStatus.missing),
      detail: present
          ? BetaReleaseQaCopy.detailSet
          : BetaReleaseQaCopy.detailMissing,
    );
  }

  static BetaReleaseQaRow _firstUsePromptRow() {
    final available =
        RecordFirstUsePromptCopy.title.isNotEmpty &&
        RecordFirstUsePromptCopy.body.isNotEmpty;
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.firstUsePromptAvailable,
      label: BetaReleaseQaCopy.rowFirstUsePromptAvailable,
      status: available
          ? BetaReleaseQaStatus.ready
          : BetaReleaseQaStatus.missing,
    );
  }

  static BetaReleaseQaRow _testerMissionRow() {
    final available =
        ArchiveBetaMissionGate.isEnabled && TesterMissionCopy.title.isNotEmpty;
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.testerMissionAvailable,
      label: BetaReleaseQaCopy.rowTesterMissionAvailable,
      status: available
          ? BetaReleaseQaStatus.ready
          : BetaReleaseQaStatus.missing,
    );
  }

  static BetaReleaseQaRow _firstProofPathRow() => const BetaReleaseQaRow(
    id: BetaReleaseQaRowId.firstProofPathAvailable,
    label: BetaReleaseQaCopy.rowFirstProofPathAvailable,
    status: BetaReleaseQaStatus.ready,
  );

  static BetaReleaseQaRow _returnCheckPathRow() => const BetaReleaseQaRow(
    id: BetaReleaseQaRowId.returnCheckPathAvailable,
    label: BetaReleaseQaCopy.rowReturnCheckPathAvailable,
    status: BetaReleaseQaStatus.ready,
  );

  static BetaReleaseQaRow _evidenceTimelineRow() => const BetaReleaseQaRow(
    id: BetaReleaseQaRowId.evidenceTimelineAvailable,
    label: BetaReleaseQaCopy.rowEvidenceTimelineAvailable,
    status: BetaReleaseQaStatus.ready,
  );

  static BetaReleaseQaRow _privateReportPreviewRow() => const BetaReleaseQaRow(
    id: BetaReleaseQaRowId.privateReportPreviewAvailable,
    label: BetaReleaseQaCopy.rowPrivateReportPreviewAvailable,
    status: BetaReleaseQaStatus.ready,
  );

  static BetaReleaseQaRow _proBridgeRouteRow() {
    final available =
        proBridgeRouteAvailableOverride ??
        BetaReleaseQaCopy.proBridgeRoute.isNotEmpty;
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.proBridgeRouteAvailable,
      label: BetaReleaseQaCopy.rowProBridgeRouteAvailable,
      status: available
          ? BetaReleaseQaStatus.ready
          : BetaReleaseQaStatus.missing,
    );
  }

  static BetaReleaseQaRow _activationDropoffReviewRow() {
    final review = ActivationDropoffReviewEngine.build(
      counters: const ActivationDropoffCounters(),
    );
    final status = review.rows.isNotEmpty
        ? (ArchiveBetaDebugGate.showLoopDebugControls
              ? BetaReleaseQaStatus.ready
              : BetaReleaseQaStatus.checkManually)
        : BetaReleaseQaStatus.missing;
    return BetaReleaseQaRow(
      id: BetaReleaseQaRowId.activationDropoffReviewAvailable,
      label: BetaReleaseQaCopy.rowActivationDropoffReviewAvailable,
      status: status,
    );
  }

  static bool _apiBaseUrlPresent() =>
      AppConfig.isBackendConfigured && AppConfig.apiBaseUrl.isNotEmpty;

  static bool _revenueCatKeyPresent() {
    if (Platform.isIOS) {
      const key = String.fromEnvironment(
        'REVENUECAT_IOS_API_KEY',
        defaultValue: '',
      );
      if (key.trim().isNotEmpty) return true;
    }
    if (Platform.isAndroid) {
      const key = String.fromEnvironment(
        'REVENUECAT_ANDROID_API_KEY',
        defaultValue: '',
      );
      if (key.trim().isNotEmpty) return true;
    }
    const fallback = String.fromEnvironment(
      'REVENUECAT_API_KEY',
      defaultValue: '',
    );
    return fallback.trim().isNotEmpty;
  }

  @visibleForTesting
  static void resetForTest() {
    apiBaseUrlPresentOverride = null;
    revenueCatKeyPresentOverride = null;
    proBridgeRouteAvailableOverride = null;
  }
}
