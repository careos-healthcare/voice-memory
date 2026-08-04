import 'archive_prompt_assist_copy.dart';

/// Archive prompt assist — one safe recording prompt from prior repeats, not chat.
abstract final class ArchivePromptAssist {
  ArchivePromptAssist._();

  static ArchivePromptAssistResult build(ArchivePromptAssistInput input) {
    if (input.userRecentlyCorrectedProof) {
      return ArchivePromptAssistResult.hidden(
        reason: ArchivePromptAssistReason.hiddenAfterCorrection,
      );
    }
    if (input.isPrivateRawText) {
      return ArchivePromptAssistResult.hidden(
        reason: ArchivePromptAssistReason.hiddenPrivateRawText,
      );
    }
    if (input.isWatchOnly) {
      return ArchivePromptAssistResult.hidden(
        reason: ArchivePromptAssistReason.hiddenWatchOnly,
      );
    }
    if (input.isGenericOrRejected) {
      return ArchivePromptAssistResult.hidden(
        reason: ArchivePromptAssistReason.hiddenGenericOrRejected,
      );
    }
    if (input.hasSafeRepeat &&
        input.hasEnoughArchiveSignal &&
        input.safeRepeatPhrase.trim().isNotEmpty) {
      return ArchivePromptAssistResult(
        shouldShowPrompt: true,
        promptText: ArchivePromptAssistCopy.safeRepeatPrompt(
          input.safeRepeatPhrase.trim(),
        ),
        reason: ArchivePromptAssistReason.safeRepeatPrompt,
      );
    }
    if (!input.hasSafeRepeat || !input.hasEnoughArchiveSignal) {
      return ArchivePromptAssistResult(
        shouldShowPrompt: true,
        promptText: ArchivePromptAssistCopy.fallbackPrompt,
        reason: ArchivePromptAssistReason.fallbackRepeatPrompt,
      );
    }
    return ArchivePromptAssistResult(
      shouldShowPrompt: true,
      promptText: ArchivePromptAssistCopy.fallbackPrompt,
      reason: ArchivePromptAssistReason.fallbackRepeatPrompt,
    );
  }
}

enum ArchivePromptAssistReason {
  safeRepeatPrompt,
  fallbackRepeatPrompt,
  hiddenNoSafeSignal,
  hiddenAfterCorrection,
  hiddenWatchOnly,
  hiddenGenericOrRejected,
  hiddenPrivateRawText,
}

class ArchivePromptAssistInput {
  const ArchivePromptAssistInput({
    required this.hasSafeRepeat,
    required this.safeRepeatPhrase,
    required this.hasEnoughArchiveSignal,
    required this.userRecentlyCorrectedProof,
    required this.isWatchOnly,
    required this.isGenericOrRejected,
    required this.isPrivateRawText,
  });

  final bool hasSafeRepeat;
  final String safeRepeatPhrase;
  final bool hasEnoughArchiveSignal;
  final bool userRecentlyCorrectedProof;
  final bool isWatchOnly;
  final bool isGenericOrRejected;
  final bool isPrivateRawText;
}

class ArchivePromptAssistResult {
  const ArchivePromptAssistResult({
    required this.shouldShowPrompt,
    required this.promptText,
    required this.reason,
  });

  factory ArchivePromptAssistResult.hidden({
    required ArchivePromptAssistReason reason,
  }) => ArchivePromptAssistResult(
    shouldShowPrompt: false,
    promptText: '',
    reason: reason,
  );

  final bool shouldShowPrompt;
  final String promptText;
  final ArchivePromptAssistReason reason;
}
