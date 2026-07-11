import 'post_save_reinforcement_placement_copy.dart';

/// Post-save reinforcement placement — show calm reinforcement after save only.
abstract final class PostSaveReinforcementPlacement {
  PostSaveReinforcementPlacement._();

  static PostSaveReinforcementPlacementResult build(
    PostSaveReinforcementPlacementInput input,
  ) {
    if (!input.isPostSave) {
      return _hidden(PostSaveReinforcementPlacementReason.hideNotPostSave);
    }
    if (!input.savedMoment) {
      return _hidden(PostSaveReinforcementPlacementReason.hideNoSavedMoment);
    }
    if (input.isPrivateRawText) {
      return _hidden(PostSaveReinforcementPlacementReason.hidePrivateRawText);
    }
    if (input.userCorrectedProofRecently ||
        input.surface == PostSaveReinforcementPlacementSurface.afterCorrection) {
      return _hidden(PostSaveReinforcementPlacementReason.hideAfterCorrection);
    }
    if (input.isWatchOnly ||
        input.surface == PostSaveReinforcementPlacementSurface.watchOnly) {
      return _hidden(PostSaveReinforcementPlacementReason.hideWatchOnly);
    }
    if (input.wouldCompeteWithFirstProof) {
      return _hidden(
        PostSaveReinforcementPlacementReason.hideWouldCompeteWithFirstProof,
      );
    }
    if (input.wouldPressureMoreRecording) {
      return _hidden(
        PostSaveReinforcementPlacementReason.hideWouldPressureMoreRecording,
      );
    }
    if (input.isFirstMoment ||
        input.surface == PostSaveReinforcementPlacementSurface.afterFirstSave) {
      return _shown(
        message: PostSaveReinforcementPlacementCopy.firstMomentLine,
        reason: PostSaveReinforcementPlacementReason.showFirstMomentSaved,
      );
    }
    if (input.isRelatedToPreviousRepeat && input.hasSafeRepeat) {
      return _shown(
        message: PostSaveReinforcementPlacementCopy.repeatRelatedLine,
        reason: PostSaveReinforcementPlacementReason.showRepeatRelatedMomentSaved,
      );
    }
    if (!input.hasEnoughArchiveSignal) {
      return _shown(
        message: PostSaveReinforcementPlacementCopy.notEnoughProofLine,
        reason: PostSaveReinforcementPlacementReason.showNotEnoughProofYet,
      );
    }
    return _shown(
      message: PostSaveReinforcementPlacementCopy.simpleMomentLine,
      reason: PostSaveReinforcementPlacementReason.showSimpleMomentSaved,
    );
  }

  static PostSaveReinforcementPlacementReport report(
    PostSaveReinforcementPlacementResult result,
  ) =>
      PostSaveReinforcementPlacementReport(
        headline: PostSaveReinforcementPlacementCopy.headline,
        body: PostSaveReinforcementPlacementCopy.body,
        firstMomentLine: PostSaveReinforcementPlacementCopy.firstMomentLine,
        simpleMomentLine: PostSaveReinforcementPlacementCopy.simpleMomentLine,
        repeatRelatedLine: PostSaveReinforcementPlacementCopy.repeatRelatedLine,
        notEnoughProofLine: PostSaveReinforcementPlacementCopy.notEnoughProofLine,
        noPressureLine: PostSaveReinforcementPlacementCopy.noPressureLine,
        nextLine: PostSaveReinforcementPlacementCopy.nextLine,
        guardrail: PostSaveReinforcementPlacementCopy.guardrail,
        result: result,
      );

  static PostSaveReinforcementPlacementResult _shown({
    required String message,
    required PostSaveReinforcementPlacementReason reason,
  }) =>
      PostSaveReinforcementPlacementResult(
        shouldShow: true,
        message: message,
        reason: reason,
      );

  static PostSaveReinforcementPlacementResult _hidden(
    PostSaveReinforcementPlacementReason reason,
  ) =>
      PostSaveReinforcementPlacementResult(
        shouldShow: false,
        message: '',
        reason: reason,
      );
}

enum PostSaveReinforcementPlacementSurface {
  afterFirstSave,
  afterSimpleSave,
  afterRepeatRelatedSave,
  afterWeakEvidenceSave,
  afterCorrection,
  watchOnly,
  privateRawText,
  noSave,
}

enum PostSaveReinforcementPlacementReason {
  showFirstMomentSaved,
  showSimpleMomentSaved,
  showRepeatRelatedMomentSaved,
  showNotEnoughProofYet,
  hideNoSavedMoment,
  hideAfterCorrection,
  hideWatchOnly,
  hidePrivateRawText,
  hideWouldCompeteWithFirstProof,
  hideWouldPressureMoreRecording,
  hideNotPostSave,
}

class PostSaveReinforcementPlacementInput {
  const PostSaveReinforcementPlacementInput({
    required this.surface,
    required this.savedMoment,
    required this.isFirstMoment,
    required this.isRelatedToPreviousRepeat,
    required this.hasSafeRepeat,
    required this.hasEnoughArchiveSignal,
    required this.userCorrectedProofRecently,
    required this.isWatchOnly,
    required this.isPrivateRawText,
    required this.isPostSave,
    required this.isRecordScreen,
    required this.wouldCompeteWithFirstProof,
    required this.wouldPressureMoreRecording,
  });

  final PostSaveReinforcementPlacementSurface surface;
  final bool savedMoment;
  final bool isFirstMoment;
  final bool isRelatedToPreviousRepeat;
  final bool hasSafeRepeat;
  final bool hasEnoughArchiveSignal;
  final bool userCorrectedProofRecently;
  final bool isWatchOnly;
  final bool isPrivateRawText;
  final bool isPostSave;
  final bool isRecordScreen;
  final bool wouldCompeteWithFirstProof;
  final bool wouldPressureMoreRecording;
}

class PostSaveReinforcementPlacementResult {
  const PostSaveReinforcementPlacementResult({
    required this.shouldShow,
    required this.message,
    required this.reason,
  });

  final bool shouldShow;
  final String message;
  final PostSaveReinforcementPlacementReason reason;
}

class PostSaveReinforcementPlacementReport {
  const PostSaveReinforcementPlacementReport({
    required this.headline,
    required this.body,
    required this.firstMomentLine,
    required this.simpleMomentLine,
    required this.repeatRelatedLine,
    required this.notEnoughProofLine,
    required this.noPressureLine,
    required this.nextLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String firstMomentLine;
  final String simpleMomentLine;
  final String repeatRelatedLine;
  final String notEnoughProofLine;
  final String noPressureLine;
  final String nextLine;
  final String guardrail;
  final PostSaveReinforcementPlacementResult result;
}
