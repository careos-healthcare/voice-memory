import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/early_archive/private_archive_report_gates.dart';
import 'package:archiveme_mobile/features/open_capture/open_capture_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Visibility rules for beta proof feedback rows — no proof output changes.
abstract final class BetaProofFeedbackEngine {
  BetaProofFeedbackEngine._();

  static bool shouldShow({
    required BetaProofFeedbackSurface surface,
    required bool parentVisible,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (!parentVisible) return false;
    if (isRecording) return false;
    if (isPostSaveDegraded) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (BetaProofFeedbackStore.isAnsweredToday(surface)) return false;
    return true;
  }

  static bool shouldShowOnFirstProofPayoff({
    required bool showFirstProofPayoff,
    required bool firstProofPayoffVisible,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      showFirstProofPayoff &&
      shouldShow(
        surface: BetaProofFeedbackSurface.firstProofPayoff,
        parentVisible: firstProofPayoffVisible,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
        isRecording: isRecording,
        isPostSaveDegraded: isPostSaveDegraded,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShowOnPrivateArchiveReportPreview({
    required bool privateArchiveReportVisible,
    required bool isPro,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      PrivateArchiveReportGates.showPreviewNote(isPro: isPro) &&
      shouldShow(
        surface: BetaProofFeedbackSurface.privateArchiveReportPreview,
        parentVisible: privateArchiveReportVisible,
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
        isRecording: isRecording,
        isPostSaveDegraded: isPostSaveDegraded,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => OpenCaptureEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}