import 'next_best_action_model.dart';

/// Visibility gates for the next best action line.
abstract final class NextBestActionGates {
  NextBestActionGates._();

  static bool shouldShow({
    required NextBestActionResult? action,
    required NextBestActionSurface surface,
    required bool showEarlyRepeatProgress,
    required bool showPostSaveReturnCheckAnswer,
    required bool repeatReturnCheckOfferVisible,
    required bool showPatternChangedCard,
    required bool showHelpfulActionCard,
    required bool showPrivateArchiveReportCard,
  }) {
    if (action == null) return false;

    if (surface == NextBestActionSurface.patterns &&
        action.kind == NextBestActionKind.returnCheckAnswered) {
      return false;
    }

    if (showEarlyRepeatProgress && _isEarlyStage(action.kind)) {
      return false;
    }

    if (action.kind == NextBestActionKind.returnCheckUnanswered &&
        (showPostSaveReturnCheckAnswer || repeatReturnCheckOfferVisible)) {
      return false;
    }

    if (action.kind == NextBestActionKind.patternChanged &&
        showPatternChangedCard) {
      return false;
    }

    if (action.kind == NextBestActionKind.helpfulActionAppeared &&
        showHelpfulActionCard) {
      return false;
    }

    if (action.kind == NextBestActionKind.privateReportForming &&
        showPrivateArchiveReportCard) {
      return false;
    }

    return true;
  }

  static bool _isEarlyStage(NextBestActionKind kind) =>
      kind == NextBestActionKind.oneEntry ||
      kind == NextBestActionKind.twoNoClearMatch ||
      kind == NextBestActionKind.twoRelated;
}
