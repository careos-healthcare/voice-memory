import '../archive_controls/archive_control_copy.dart';
import '../beta_feedback/beta_feedback_copy.dart';
import '../first_proof_action_loop/first_proof_action_loop_copy.dart';
import '../pattern_naming/pattern_name_copy.dart';
import '../privacy_trust/privacy_trust_copy.dart';
import '../transcript_correction/transcript_correction_copy.dart';
import 'pattern_correction_model.dart';

/// Calm copy for pattern correction — no blame, no unsupported claims.
abstract final class PatternCorrectionCopy {
  PatternCorrectionCopy._();

  static const controlLabel = 'ArchiveMe got this wrong';
  static const sheetTitle = 'What feels wrong?';
  static const actionsHeading = 'What would help?';
  static const backToReasons = 'Back';

  static const wrongPatternReason = 'Wrong pattern';
  static const wrongWordingReason = 'Wrong wording';
  static const tooPersonalReason = 'Too personal';
  static const doesNotBelongReason = 'This moment does not belong';
  static const notUsefulReason = 'Not useful';

  static const renamePatternAction = FirstProofActionLoopCopy.renamePatternCta;
  static const removeFromPatternAction =
      ArchiveControlCopy.excludeFromPatternButton;
  static const correctTranscriptAction = TranscriptCorrectionCopy.actionLabel;
  static const deleteMomentAction = ArchiveControlCopy.deleteMomentButton;
  static const privacyCentreAction = PrivacyTrustCopy.title;
  static const betaFeedbackAction = BetaFeedbackCopy.sheetLinkLabel;
  static const keepRecordingAction = FirstProofActionLoopCopy.keepRecordingCta;

  static String reasonLabel(PatternCorrectionReason reason) =>
      switch (reason) {
        PatternCorrectionReason.wrongPattern => wrongPatternReason,
        PatternCorrectionReason.wrongWording => wrongWordingReason,
        PatternCorrectionReason.tooPersonal => tooPersonalReason,
        PatternCorrectionReason.doesNotBelong => doesNotBelongReason,
        PatternCorrectionReason.notUseful => notUsefulReason,
      };

  static String actionLabel(PatternCorrectionAction action) =>
      switch (action) {
        PatternCorrectionAction.renamePattern => renamePatternAction,
        PatternCorrectionAction.removeFromPattern => removeFromPatternAction,
        PatternCorrectionAction.correctTranscript => correctTranscriptAction,
        PatternCorrectionAction.deleteMoment => deleteMomentAction,
        PatternCorrectionAction.privacyCentre => privacyCentreAction,
        PatternCorrectionAction.betaFeedback => betaFeedbackAction,
        PatternCorrectionAction.keepRecording => keepRecordingAction,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield controlLabel;
    yield sheetTitle;
    yield actionsHeading;
    yield backToReasons;
    yield wrongPatternReason;
    yield wrongWordingReason;
    yield tooPersonalReason;
    yield doesNotBelongReason;
    yield notUsefulReason;
    yield renamePatternAction;
    yield removeFromPatternAction;
    yield correctTranscriptAction;
    yield deleteMomentAction;
    yield privacyCentreAction;
    yield betaFeedbackAction;
    yield keepRecordingAction;
    yield PatternNameCopy.renameSheetTitle;
  }
}
