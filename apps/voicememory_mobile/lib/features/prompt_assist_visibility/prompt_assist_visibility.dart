import 'prompt_assist_visibility_copy.dart';

/// Prompt assist visibility — show safe prompts in the first low-effort journey.
abstract final class PromptAssistVisibility {
  PromptAssistVisibility._();

  static PromptAssistVisibilityResult build(PromptAssistVisibilityInput input) {
    if (input.isPrivateRawText) {
      return _hidden(PromptAssistVisibilityReason.hidePrivateRawText);
    }
    if (input.userRecentlyCorrectedProof) {
      return _hidden(PromptAssistVisibilityReason.hideAfterCorrection);
    }
    if (input.isDailyPrompt) {
      return _hidden(PromptAssistVisibilityReason.hideDailyPrompt);
    }
    if (input.isChatLike) {
      return _hidden(PromptAssistVisibilityReason.hideChatLike);
    }
    if (input.surface == PromptAssistVisibilitySurface.correctionMode) {
      return _hidden(PromptAssistVisibilityReason.hideAfterCorrection);
    }
    if (input.surface == PromptAssistVisibilitySurface.watchOnly) {
      return _hidden(PromptAssistVisibilityReason.hideWatchOnly);
    }
    if (input.userAskedForHelpWhatToSay) {
      return _showUserAsked(input);
    }
    if (_hasSafeRepeatPrompt(input)) {
      return _shown(
        promptText: PromptAssistVisibilityCopy.safeRepeatPrompt(
          input.hasSafeRepeatPhrase.trim(),
        ),
        reason: PromptAssistVisibilityReason.showSafeRepeatPrompt,
      );
    }
    if (input.surface == PromptAssistVisibilitySurface.firstSession) {
      return _shown(
        promptText: PromptAssistVisibilityCopy.fallbackLine,
        reason: PromptAssistVisibilityReason.showFirstSessionFallback,
      );
    }
    if (input.surface == PromptAssistVisibilitySurface.recordReady) {
      return _shown(
        promptText: PromptAssistVisibilityCopy.fallbackLine,
        reason: PromptAssistVisibilityReason.showRecordReadyFallback,
      );
    }
    return _hidden(PromptAssistVisibilityReason.hideNoSafeSignal);
  }

  static PromptAssistVisibilityReport report(
    PromptAssistVisibilityResult result,
  ) => PromptAssistVisibilityReport(
    headline: PromptAssistVisibilityCopy.headline,
    body: PromptAssistVisibilityCopy.body,
    safeRepeatLine: PromptAssistVisibilityCopy.safeRepeatLine,
    fallbackLine: PromptAssistVisibilityCopy.fallbackLine,
    whyLine: PromptAssistVisibilityCopy.whyLine,
    archiveSignalLine: PromptAssistVisibilityCopy.archiveSignalLine,
    lowEffortLine: PromptAssistVisibilityCopy.lowEffortLine,
    notChatLine: PromptAssistVisibilityCopy.notChatLine,
    guardrail: PromptAssistVisibilityCopy.guardrail,
    result: result,
  );

  static bool _hasSafeRepeatPrompt(PromptAssistVisibilityInput input) =>
      input.hasSafeRepeat &&
      input.hasSafeRepeatPhrase.trim().isNotEmpty &&
      input.hasEnoughArchiveSignal;

  static PromptAssistVisibilityResult _showUserAsked(
    PromptAssistVisibilityInput input,
  ) {
    if (_hasSafeRepeatPrompt(input)) {
      return _shown(
        promptText: PromptAssistVisibilityCopy.safeRepeatPrompt(
          input.hasSafeRepeatPhrase.trim(),
        ),
        reason: PromptAssistVisibilityReason.showUserAskedForHelp,
      );
    }
    return _shown(
      promptText: PromptAssistVisibilityCopy.fallbackLine,
      reason: PromptAssistVisibilityReason.showUserAskedForHelp,
    );
  }

  static PromptAssistVisibilityResult _shown({
    required String promptText,
    required PromptAssistVisibilityReason reason,
  }) => PromptAssistVisibilityResult(
    shouldShow: true,
    promptText: promptText,
    reason: reason,
  );

  static PromptAssistVisibilityResult _hidden(
    PromptAssistVisibilityReason reason,
  ) => PromptAssistVisibilityResult(
    shouldShow: false,
    promptText: '',
    reason: reason,
  );
}

enum PromptAssistVisibilitySurface {
  firstSession,
  recordReady,
  postSave,
  returningUser,
  firstProofAvailable,
  correctionMode,
  watchOnly,
  noSafeSignal,
}

enum PromptAssistVisibilityReason {
  showFirstSessionFallback,
  showRecordReadyFallback,
  showSafeRepeatPrompt,
  showUserAskedForHelp,
  hideAfterCorrection,
  hidePrivateRawText,
  hideWatchOnly,
  hideNoSafeSignal,
  hideDailyPrompt,
  hideChatLike,
}

class PromptAssistVisibilityInput {
  const PromptAssistVisibilityInput({
    required this.surface,
    required this.hasSafeRepeat,
    required this.hasSafeRepeatPhrase,
    required this.hasEnoughArchiveSignal,
    required this.userHasSavedFirstMoment,
    required this.userHasFirstUsefulProof,
    required this.userRecentlyCorrectedProof,
    required this.isPrivateRawText,
    required this.userAskedForHelpWhatToSay,
    required this.isDailyPrompt,
    required this.isChatLike,
  });

  final PromptAssistVisibilitySurface surface;
  final bool hasSafeRepeat;
  final String hasSafeRepeatPhrase;
  final bool hasEnoughArchiveSignal;
  final bool userHasSavedFirstMoment;
  final bool userHasFirstUsefulProof;
  final bool userRecentlyCorrectedProof;
  final bool isPrivateRawText;
  final bool userAskedForHelpWhatToSay;
  final bool isDailyPrompt;
  final bool isChatLike;
}

class PromptAssistVisibilityResult {
  const PromptAssistVisibilityResult({
    required this.shouldShow,
    required this.promptText,
    required this.reason,
  });

  final bool shouldShow;
  final String promptText;
  final PromptAssistVisibilityReason reason;
}

class PromptAssistVisibilityReport {
  const PromptAssistVisibilityReport({
    required this.headline,
    required this.body,
    required this.safeRepeatLine,
    required this.fallbackLine,
    required this.whyLine,
    required this.archiveSignalLine,
    required this.lowEffortLine,
    required this.notChatLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String safeRepeatLine;
  final String fallbackLine;
  final String whyLine;
  final String archiveSignalLine;
  final String lowEffortLine;
  final String notChatLine;
  final String guardrail;
  final PromptAssistVisibilityResult result;
}
