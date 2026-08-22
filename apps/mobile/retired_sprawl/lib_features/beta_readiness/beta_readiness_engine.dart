import 'package:archiveme_mobile/features/archive_controls/archive_control_copy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_copy.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_activation/beta_activation_summary_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta_readiness/beta_readiness_copy.dart';
import 'package:archiveme_mobile/features/beta_readiness/beta_readiness_model.dart';
import 'package:archiveme_mobile/features/first_proof_action_loop/first_proof_action_loop_copy.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_copy.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_copy.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_copy.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/record/record_empty_archive_gates.dart';
import 'package:archiveme_mobile/features/record/record_home_surface_policy.dart';
import 'package:archiveme_mobile/features/retention/return_tomorrow_cue_copy.dart';
import 'package:archiveme_mobile/features/return_day/return_day_flow_copy.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_copy.dart';
import 'package:archiveme_mobile/record/record_screen_framing_copy.dart';

/// Read-only beta readiness checks — no journal access, network, or mutations.
abstract final class BetaReadinessEngine {
  BetaReadinessEngine._();

  static BetaReadinessReport build() {
    return BetaReadinessReport(
      title: BetaReadinessCopy.sheetTitle,
      intro: BetaReadinessCopy.sheetIntro,
      sections: [
        _captureSection(),
        _firstProofSection(),
        _trustControlsSection(),
        _returnLoopSection(),
        _betaFeedbackSection(),
      ],
      warnings: _releaseWarnings(),
    );
  }

  static BetaReadinessSection _captureSection() {
    return BetaReadinessSection(
      id: BetaReadinessSectionId.capture,
      title: BetaReadinessCopy.sectionCapture,
      items: [
        _item(
          id: BetaReadinessItemId.firstUseOnboardingAtZero,
          label: BetaReadinessCopy.itemFirstUseOnboardingAtZero,
          status: _firstUseOnboardingStatus(),
        ),
        _item(
          id: BetaReadinessItemId.micCtaPrimary,
          label: BetaReadinessCopy.itemMicCtaPrimary,
          status: _micCtaPrimaryStatus(),
        ),
        _item(
          id: BetaReadinessItemId.typedFallbackAvailable,
          label: BetaReadinessCopy.itemTypedFallbackAvailable,
          status: _typedFallbackStatus(),
        ),
        _item(
          id: BetaReadinessItemId.noDailyMapBeforeFirstSave,
          label: BetaReadinessCopy.itemNoDailyMapBeforeFirstSave,
          status: _noDailyMapBeforeFirstSaveStatus(),
        ),
      ],
    );
  }

  static BetaReadinessSection _firstProofSection() {
    return BetaReadinessSection(
      id: BetaReadinessSectionId.firstProof,
      title: BetaReadinessCopy.sectionFirstProof,
      items: [
        _item(
          id: BetaReadinessItemId.threeMomentsUnlockFirstProof,
          label: BetaReadinessCopy.itemThreeMomentsUnlockFirstProof,
          status: _threeMomentsUnlockStatus(),
        ),
        _item(
          id: BetaReadinessItemId.genericEntriesNoFirstProof,
          label: BetaReadinessCopy.itemGenericEntriesNoFirstProof,
          status: _genericEntriesGuardStatus(),
        ),
        _item(
          id: BetaReadinessItemId.firstProofPayoffAppears,
          label: BetaReadinessCopy.itemFirstProofPayoffAppears,
          status: _firstProofPayoffStatus(),
        ),
        _item(
          id: BetaReadinessItemId.firstProofTruthFollowUp,
          label: BetaReadinessCopy.itemFirstProofTruthFollowUp,
          status: _firstProofTruthStatus(),
        ),
        _item(
          id: BetaReadinessItemId.firstProofActionLoopAfterAnswer,
          label: BetaReadinessCopy.itemFirstProofActionLoopAfterAnswer,
          status: _firstProofActionLoopStatus(),
        ),
      ],
    );
  }

  static BetaReadinessSection _trustControlsSection() {
    return BetaReadinessSection(
      id: BetaReadinessSectionId.trustControls,
      title: BetaReadinessCopy.sectionTrustControls,
      items: [
        _item(
          id: BetaReadinessItemId.savedMomentsOpens,
          label: BetaReadinessCopy.itemSavedMomentsOpens,
          status: _copyAvailable(
            ArchiveHistoryCopy.sheetTitle.isNotEmpty &&
                ArchiveHistoryCopy.sheetSubtitle.isNotEmpty,
          ),
        ),
        _item(
          id: BetaReadinessItemId.deleteMomentAvailable,
          label: BetaReadinessCopy.itemDeleteMomentAvailable,
          status: _copyAvailable(
            ArchiveControlCopy.deleteMomentButton.isNotEmpty &&
                ArchiveControlCopy.deleteDialogTitle.isNotEmpty,
          ),
        ),
        _item(
          id: BetaReadinessItemId.removeFromPatternAvailable,
          label: BetaReadinessCopy.itemRemoveFromPatternAvailable,
          status: _copyAvailable(
            ArchiveControlCopy.excludeFromPatternButton.isNotEmpty &&
                ArchiveControlCopy.excludeDialogTitle.isNotEmpty,
          ),
        ),
        _item(
          id: BetaReadinessItemId.correctTranscriptAvailable,
          label: BetaReadinessCopy.itemCorrectTranscriptAvailable,
          status: _copyAvailable(
            TranscriptCorrectionCopy.actionLabel.isNotEmpty &&
                PrivacyTrustCopy.correctTranscriptControl.isNotEmpty,
          ),
        ),
        _item(
          id: BetaReadinessItemId.privacyCentreOpens,
          label: BetaReadinessCopy.itemPrivacyCentreOpens,
          status: _copyAvailable(
            PrivacyTrustCopy.title.isNotEmpty &&
                PrivacyTrustCopy.yourControlsHeading.isNotEmpty,
          ),
        ),
        _item(
          id: BetaReadinessItemId.exportLocalBackupAvailable,
          label: BetaReadinessCopy.itemExportLocalBackupAvailable,
          status: _copyAvailable(
            LocalBackupCopy.exportControl.isNotEmpty &&
                LocalBackupCopy.exportBody.isNotEmpty,
          ),
        ),
        _item(
          id: BetaReadinessItemId.restoreLocalBackupAvailable,
          label: BetaReadinessCopy.itemRestoreLocalBackupAvailable,
          status: _copyAvailable(
            LocalBackupCopy.restoreControl.isNotEmpty &&
                LocalBackupCopy.restoreBody.isNotEmpty,
          ),
        ),
      ],
    );
  }

  static BetaReadinessSection _returnLoopSection() {
    return BetaReadinessSection(
      id: BetaReadinessSectionId.returnLoop,
      title: BetaReadinessCopy.sectionReturnLoop,
      items: [
        _item(
          id: BetaReadinessItemId.returnTomorrowCue,
          label: BetaReadinessCopy.itemReturnTomorrowCue,
          status: _returnTomorrowCueStatus(),
        ),
        _item(
          id: BetaReadinessItemId.returnDayFlowAvailable,
          label: BetaReadinessCopy.itemReturnDayFlowAvailable,
          status: _returnDayFlowStatus(),
        ),
        _item(
          id: BetaReadinessItemId.whatChangedAfterFourthMoment,
          label: BetaReadinessCopy.itemWhatChangedAfterFourthMoment,
          status: _whatChangedStatus(),
        ),
      ],
    );
  }

  static BetaReadinessSection _betaFeedbackSection() {
    final betaEnabled = ArchiveBetaMissionGate.isEnabled;
    return BetaReadinessSection(
      id: BetaReadinessSectionId.betaFeedback,
      title: BetaReadinessCopy.sectionBetaFeedback,
      items: [
        _item(
          id: BetaReadinessItemId.sendBetaFeedbackAvailable,
          label: BetaReadinessCopy.itemSendBetaFeedbackAvailable,
          status:
              betaEnabled &&
                  BetaFeedbackCopy.sheetLinkLabel.isNotEmpty &&
                  BetaFeedbackCopy.sheetTitle.isNotEmpty
              ? BetaReadinessItemStatus.pass
              : BetaReadinessItemStatus.notAvailable,
        ),
        _item(
          id: BetaReadinessItemId.betaProgressSummaryAvailable,
          label: BetaReadinessCopy.itemBetaProgressSummaryAvailable,
          status:
              betaEnabled &&
                  BetaActivationSummaryCopy.openLink.isNotEmpty &&
                  BetaActivationSummaryCopy.sheetTitle.isNotEmpty
              ? BetaReadinessItemStatus.pass
              : BetaReadinessItemStatus.notAvailable,
        ),
        _item(
          id: BetaReadinessItemId.copySummaryWorks,
          label: BetaReadinessCopy.itemCopySummaryWorks,
          status:
              betaEnabled && BetaActivationSummaryCopy.summaryCopied.isNotEmpty
              ? BetaReadinessItemStatus.needsManualCheck
              : BetaReadinessItemStatus.notAvailable,
        ),
      ],
    );
  }

  static List<BetaReadinessWarning> _releaseWarnings() => const [
    BetaReadinessWarning(text: BetaReadinessCopy.warningAppStoreProducts),
    BetaReadinessWarning(text: BetaReadinessCopy.warningLocalBackupPlainJson),
    BetaReadinessWarning(
      text: BetaReadinessCopy.warningArchiveLocalUnlessExport,
    ),
  ];

  static BetaReadinessItemStatus _firstUseOnboardingStatus() {
    final gate = RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
      loaded: true,
      entryCount: 0,
    );
    final copyReady =
        RecordFirstUsePromptCopy.title.isNotEmpty &&
        RecordFirstUsePromptCopy.body.isNotEmpty &&
        RecordScreenFramingCopy.emptyArchiveTitle.isNotEmpty;
    if (gate && copyReady) {
      return BetaReadinessItemStatus.needsManualCheck;
    }
    return BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _micCtaPrimaryStatus() {
    final resolution = RecordCtaPolicy.resolve(
      ui: RecordUiState.ready,
      entryCount: 0,
      entryCountLoaded: true,
      showPostSaveLoop: false,
      isDegradedVoiceSave: false,
    );
    if (resolution.state == RecordCtaPolicyState.firstUse &&
        resolution.action == RecordCtaAction.startRecording &&
        (resolution.primaryLabel?.isNotEmpty ?? false)) {
      return BetaReadinessItemStatus.pass;
    }
    return BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _typedFallbackStatus() {
    return _copyAvailable(VisibleArchiveProofCopy.typeInsteadCta.isNotEmpty);
  }

  static BetaReadinessItemStatus _noDailyMapBeforeFirstSaveStatus() {
    final mapGateAtZero =
        RecordEmptyArchiveGates.showDailyArchiveExerciseOnRecord(
          loaded: true,
          entryCount: 0,
        );
    final policyAtZero = RecordHomeSurfacePolicy.resolve(
      isReady: true,
      loaded: true,
      entryCount: 0,
      screenshotMode: false,
    );
    if (!mapGateAtZero && !policyAtZero.showDailyMapPrompt) {
      return BetaReadinessItemStatus.pass;
    }
    return BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _threeMomentsUnlockStatus() {
    if (ArchiveEvidenceQualityGate.minProofEntryCount != 3) {
      return BetaReadinessItemStatus.notAvailable;
    }
    return BetaReadinessItemStatus.needsManualCheck;
  }

  static BetaReadinessItemStatus _genericEntriesGuardStatus() {
    if (ArchiveEvidenceQualityGate.minProofEntryCount != 3) {
      return BetaReadinessItemStatus.notAvailable;
    }
    return BetaReadinessItemStatus.pass;
  }

  static BetaReadinessItemStatus _firstProofPayoffStatus() {
    return FirstProofPayoffCopy.headline.isNotEmpty
        ? BetaReadinessItemStatus.needsManualCheck
        : BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _firstProofTruthStatus() {
    return FirstProofTruthCopy.question.isNotEmpty &&
            FirstProofTruthStore.answeredPrefsKey.isNotEmpty
        ? BetaReadinessItemStatus.needsManualCheck
        : BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _firstProofActionLoopStatus() {
    return FirstProofActionLoopCopy.yesTitle.isNotEmpty
        ? BetaReadinessItemStatus.needsManualCheck
        : BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _returnTomorrowCueStatus() {
    return ReturnTomorrowCueCopy.afterFirstMomentTitle.isNotEmpty &&
            ReturnTomorrowCueCopy.afterSecondRelatedTitle.isNotEmpty
        ? BetaReadinessItemStatus.needsManualCheck
        : BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _returnDayFlowStatus() {
    return ReturnDayFlowCopy.title.isNotEmpty &&
            ReturnDayFlowCopy.yesCameBack.isNotEmpty
        ? BetaReadinessItemStatus.needsManualCheck
        : BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _whatChangedStatus() {
    final gateAtFour =
        RecordEmptyArchiveGates.showConfirmedRepeatChangeNoticeCard(
          loaded: true,
          entryCount: 4,
          isPostSave: false,
        );
    return WhatChangedV2Copy.question.isNotEmpty && gateAtFour
        ? BetaReadinessItemStatus.needsManualCheck
        : BetaReadinessItemStatus.notAvailable;
  }

  static BetaReadinessItemStatus _copyAvailable(bool available) => available
      ? BetaReadinessItemStatus.pass
      : BetaReadinessItemStatus.notAvailable;

  static BetaReadinessItem _item({
    required BetaReadinessItemId id,
    required String label,
    required BetaReadinessItemStatus status,
  }) => BetaReadinessItem(id: id, label: label, status: status);
}