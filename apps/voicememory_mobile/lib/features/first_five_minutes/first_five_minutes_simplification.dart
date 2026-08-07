import 'first_five_minutes_simplification_copy.dart';

/// First-five-minutes simplification — brutal simplicity for new users.
abstract final class FirstFiveMinutesSimplification {
  FirstFiveMinutesSimplification._();

  static const firstFiveMinuteLimit = 5;

  static FirstFiveMinutesResult build(FirstFiveMinutesInput input) {
    if (_userRequestedNonCapture(input)) {
      return _show(FirstFiveMinutesReason.showUserRequestedSurface);
    }

    switch (input.surface) {
      case FirstFiveMinutesSurface.oneLinePositioning:
        if (_inFirstFiveMinutes(input)) {
          return _show(FirstFiveMinutesReason.showOneLinePositioning);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.saveRepeatPrompt:
        if (!input.hasSavedFirstMoment) {
          return _show(FirstFiveMinutesReason.showSaveRepeatPrompt);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.recordCapture:
        return _show(FirstFiveMinutesReason.showCapture);
      case FirstFiveMinutesSurface.typeInstead:
        return _show(FirstFiveMinutesReason.showCapture);
      case FirstFiveMinutesSurface.promptAssist:
        if (_inFirstFiveMinutes(input)) {
          return _show(FirstFiveMinutesReason.showPromptAssist);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.positiveReinforcement:
        if (input.isPostSave) {
          return _show(FirstFiveMinutesReason.showPositiveReinforcement);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.savedMatters:
        if (input.hasSavedFirstMoment) {
          return _show(FirstFiveMinutesReason.showSavedMatters);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.whatHappensNext:
        if (input.hasSavedFirstMoment) {
          return _show(FirstFiveMinutesReason.showWhatHappensNext);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.firstProofPreview:
        if (input.hasSavedFirstMoment || input.hasSavedSecondMoment) {
          return _show(FirstFiveMinutesReason.showFirstProofPreviewAfterSave);
        }
        return _hide(FirstFiveMinutesReason.hideTooEarly);
      case FirstFiveMinutesSurface.proExplanation:
        if (!input.hasFirstUsefulProof) {
          return _hide(FirstFiveMinutesReason.hidePaywallTooEarly);
        }
        return _show(FirstFiveMinutesReason.showWhatHappensNext);
      case FirstFiveMinutesSurface.paywall:
        if (!input.hasFirstUsefulProof) {
          return _hide(FirstFiveMinutesReason.hidePaywallTooEarly);
        }
        return _show(FirstFiveMinutesReason.showWhatHappensNext);
      case FirstFiveMinutesSurface.contextDetail:
        return _hideFirstFiveNoise(
          input,
          hideReason: FirstFiveMinutesReason.hideContextTooEarly,
        );
      case FirstFiveMinutesSurface.archiveHealth:
        return _hideFirstFiveNoise(
          input,
          hideReason: FirstFiveMinutesReason.hideReportsTooEarly,
        );
      case FirstFiveMinutesSurface.actionItems:
        return _hideFirstFiveNoise(
          input,
          hideReason: FirstFiveMinutesReason.hideActionItemsTooEarly,
        );
      case FirstFiveMinutesSurface.reports:
        return _hide(FirstFiveMinutesReason.hideReportsTooEarly);
      case FirstFiveMinutesSurface.quickActions:
        return _hide(FirstFiveMinutesReason.hideFeatureNoise);
      case FirstFiveMinutesSurface.workspace:
        return _hideFirstFiveNoise(
          input,
          hideReason: FirstFiveMinutesReason.hideWorkspaceTooEarly,
        );
      case FirstFiveMinutesSurface.debugReadiness:
        if (input.isStoreReadinessMode) {
          return _show(FirstFiveMinutesReason.showDebugReadiness);
        }
        return _hide(FirstFiveMinutesReason.hideFeatureNoise);
    }
  }

  static FirstFiveMinutesReport report(
    FirstFiveMinutesResult result,
  ) => FirstFiveMinutesReport(
    headline: FirstFiveMinutesSimplificationCopy.headline,
    body: FirstFiveMinutesSimplificationCopy.body,
    oneLinePositioning: FirstFiveMinutesSimplificationCopy.oneLinePositioning,
    whenToUseLine: FirstFiveMinutesSimplificationCopy.whenToUseLine,
    oneSentenceLine: FirstFiveMinutesSimplificationCopy.oneSentenceLine,
    savedMattersLine: FirstFiveMinutesSimplificationCopy.savedMattersLine,
    whatHappensNextLine: FirstFiveMinutesSimplificationCopy.whatHappensNextLine,
    notNowLine: FirstFiveMinutesSimplificationCopy.notNowLine,
    notChatLine: FirstFiveMinutesSimplificationCopy.notChatLine,
    notStorageLine: FirstFiveMinutesSimplificationCopy.notStorageLine,
    guardrail: FirstFiveMinutesSimplificationCopy.guardrail,
    result: result,
  );

  static String previewCopyFor(FirstFiveMinutesResult result) =>
      result.reason == FirstFiveMinutesReason.showFirstProofPreviewAfterSave
      ? FirstFiveMinutesSimplificationCopy.firstProofPreviewLine
      : '';

  static bool _inFirstFiveMinutes(FirstFiveMinutesInput input) =>
      input.minuteIndex < firstFiveMinuteLimit;

  static bool _userRequestedNonCapture(FirstFiveMinutesInput input) {
    if (!input.hasUserAskedForSurface) return false;
    return switch (input.surface) {
      FirstFiveMinutesSurface.contextDetail ||
      FirstFiveMinutesSurface.actionItems ||
      FirstFiveMinutesSurface.workspace => _inFirstFiveMinutes(input),
      _ => false,
    };
  }

  static FirstFiveMinutesResult _hideFirstFiveNoise(
    FirstFiveMinutesInput input, {
    required FirstFiveMinutesReason hideReason,
  }) {
    if (_inFirstFiveMinutes(input)) {
      return _hide(hideReason);
    }
    return _hide(FirstFiveMinutesReason.hideFeatureNoise);
  }

  static FirstFiveMinutesResult _show(FirstFiveMinutesReason reason) =>
      FirstFiveMinutesResult(shouldShow: true, reason: reason);

  static FirstFiveMinutesResult _hide(FirstFiveMinutesReason reason) =>
      FirstFiveMinutesResult(shouldShow: false, reason: reason);
}

enum FirstFiveMinutesSurface {
  oneLinePositioning,
  saveRepeatPrompt,
  recordCapture,
  typeInstead,
  promptAssist,
  positiveReinforcement,
  savedMatters,
  whatHappensNext,
  firstProofPreview,
  proExplanation,
  contextDetail,
  archiveHealth,
  actionItems,
  reports,
  quickActions,
  workspace,
  paywall,
  debugReadiness,
}

enum FirstFiveMinutesReason {
  showOneLinePositioning,
  showSaveRepeatPrompt,
  showCapture,
  showPromptAssist,
  showPositiveReinforcement,
  showSavedMatters,
  showWhatHappensNext,
  showFirstProofPreviewAfterSave,
  showUserRequestedSurface,
  showDebugReadiness,
  hideTooEarly,
  hideFeatureNoise,
  hidePaywallTooEarly,
  hideReportsTooEarly,
  hideContextTooEarly,
  hideActionItemsTooEarly,
  hideWorkspaceTooEarly,
}

class FirstFiveMinutesInput {
  const FirstFiveMinutesInput({
    required this.surface,
    required this.minuteIndex,
    required this.hasSavedFirstMoment,
    required this.hasSavedSecondMoment,
    required this.hasFirstUsefulProof,
    required this.hasUserAskedForSurface,
    required this.isStoreReadinessMode,
    required this.isPostSave,
    required this.userFeelsConfused,
  });

  final FirstFiveMinutesSurface surface;
  final int minuteIndex;
  final bool hasSavedFirstMoment;
  final bool hasSavedSecondMoment;
  final bool hasFirstUsefulProof;
  final bool hasUserAskedForSurface;
  final bool isStoreReadinessMode;
  final bool isPostSave;
  final bool userFeelsConfused;
}

class FirstFiveMinutesResult {
  const FirstFiveMinutesResult({
    required this.shouldShow,
    required this.reason,
  });

  final bool shouldShow;
  final FirstFiveMinutesReason reason;
}

class FirstFiveMinutesReport {
  const FirstFiveMinutesReport({
    required this.headline,
    required this.body,
    required this.oneLinePositioning,
    required this.whenToUseLine,
    required this.oneSentenceLine,
    required this.savedMattersLine,
    required this.whatHappensNextLine,
    required this.notNowLine,
    required this.notChatLine,
    required this.notStorageLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String oneLinePositioning;
  final String whenToUseLine;
  final String oneSentenceLine;
  final String savedMattersLine;
  final String whatHappensNextLine;
  final String notNowLine;
  final String notChatLine;
  final String notStorageLine;
  final String guardrail;
  final FirstFiveMinutesResult result;
}
