import 'package:archiveme_mobile/features/positive_archive_reinforcement/positive_archive_reinforcement_copy.dart';

/// Positive archive reinforcement — one saved moment matters, no streaks or pressure.
abstract final class PositiveArchiveReinforcement {
  PositiveArchiveReinforcement._();

  static PositiveArchiveReinforcementResult build(
    PositiveArchiveReinforcementInput input,
  ) {
    if (!input.savedMoment) {
      return PositiveArchiveReinforcementResult.hidden(
        reason: PositiveArchiveReinforcementReason.hiddenNoSavedMoment,
      );
    }
    if (input.isPrivateRawText) {
      return PositiveArchiveReinforcementResult.hidden(
        reason: PositiveArchiveReinforcementReason.hiddenPrivateRawText,
      );
    }
    if (input.userCorrectedProofRecently) {
      return PositiveArchiveReinforcementResult.hidden(
        reason: PositiveArchiveReinforcementReason.hiddenAfterCorrection,
      );
    }
    if (input.isWatchOnly) {
      return PositiveArchiveReinforcementResult.hidden(
        reason: PositiveArchiveReinforcementReason.hiddenWatchOnly,
      );
    }
    if (input.isFirstMoment) {
      return const PositiveArchiveReinforcementResult(
        shouldShow: true,
        message: PositiveArchiveReinforcementCopy.firstMomentSavedMessage,
        reason: PositiveArchiveReinforcementReason.firstMomentSaved,
      );
    }
    if (input.isRelatedToPreviousRepeat && input.hasSafeRepeat) {
      return const PositiveArchiveReinforcementResult(
        shouldShow: true,
        message:
            PositiveArchiveReinforcementCopy.repeatRelatedMomentSavedMessage,
        reason: PositiveArchiveReinforcementReason.repeatRelatedMomentSaved,
      );
    }
    if (!input.hasEnoughArchiveSignal) {
      return const PositiveArchiveReinforcementResult(
        shouldShow: true,
        message: PositiveArchiveReinforcementCopy.notEnoughProofYetMessage,
        reason: PositiveArchiveReinforcementReason.notEnoughProofYet,
      );
    }
    return const PositiveArchiveReinforcementResult(
      shouldShow: true,
      message: PositiveArchiveReinforcementCopy.simpleMomentSavedMessage,
      reason: PositiveArchiveReinforcementReason.simpleMomentSaved,
    );
  }
}

enum PositiveArchiveReinforcementReason {
  firstMomentSaved,
  simpleMomentSaved,
  repeatRelatedMomentSaved,
  notEnoughProofYet,
  hiddenAfterCorrection,
  hiddenWatchOnly,
  hiddenPrivateRawText,
  hiddenNoSavedMoment,
}

class PositiveArchiveReinforcementInput {
  const PositiveArchiveReinforcementInput({
    required this.savedMoment,
    required this.hasSafeRepeat,
    required this.hasEnoughArchiveSignal,
    required this.isFirstMoment,
    required this.isRelatedToPreviousRepeat,
    required this.userCorrectedProofRecently,
    required this.isWatchOnly,
    required this.isPrivateRawText,
  });

  final bool savedMoment;
  final bool hasSafeRepeat;
  final bool hasEnoughArchiveSignal;
  final bool isFirstMoment;
  final bool isRelatedToPreviousRepeat;
  final bool userCorrectedProofRecently;
  final bool isWatchOnly;
  final bool isPrivateRawText;
}

class PositiveArchiveReinforcementResult {
  const PositiveArchiveReinforcementResult({
    required this.shouldShow,
    required this.message,
    required this.reason,
  });

  factory PositiveArchiveReinforcementResult.hidden({
    required PositiveArchiveReinforcementReason reason,
  }) => PositiveArchiveReinforcementResult(
    shouldShow: false,
    message: '',
    reason: reason,
  );

  final bool shouldShow;
  final String message;
  final PositiveArchiveReinforcementReason reason;
}