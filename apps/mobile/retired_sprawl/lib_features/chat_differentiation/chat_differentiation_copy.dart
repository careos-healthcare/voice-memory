/// Copy explaining how ArchiveMe differs from chat — grounded, non-comparative.
abstract final class ChatDifferentiationCopy {
  ChatDifferentiationCopy._();

  static const firstProofLine =
      'ArchiveMe did not answer one message. It compared moments you saved at different times.';

  static const expandLinkLabel = 'Why this is different from chat';

  static const sheetTitle = 'Why this is different';

  static const sheetBody =
      'Chat can respond to what you say today. ArchiveMe is built to notice what returns across days, then show the evidence back to you.';

  static const timelineFirstSavedLabel = 'First saved';
  static const timelineCameBackLabel = 'Came back';
  static const timelineRepeatedAgainLabel = 'Repeated again';

  static const timelineEarlierFallback = 'Earlier';
  static const timelineLaterFallback = 'Later';
  static const timelineAgainFallback = 'Again';

  static const sheetCloseLine = 'That timeline is the product.';

  static const onboardingNotChatLine =
      'ArchiveMe is not a chat. It helps you notice what keeps returning.';

  static const patternDetailWhyHeading = 'Why this matters';
  static const patternDetailWhyBody =
      'This is not one answer. It is the same thread appearing across saved moments.';

  /// Phrases that must not appear in differentiation copy.
  static const bannedAttackPhrases = [
    'better than chatgpt',
    'chatgpt cannot',
    'ai therapist',
    'we know you',
  ];

  static List<String> allVisibleStrings() => [
    firstProofLine,
    expandLinkLabel,
    sheetTitle,
    sheetBody,
    timelineFirstSavedLabel,
    timelineCameBackLabel,
    timelineRepeatedAgainLabel,
    timelineEarlierFallback,
    timelineLaterFallback,
    timelineAgainFallback,
    sheetCloseLine,
    onboardingNotChatLine,
    patternDetailWhyHeading,
    patternDetailWhyBody,
  ];
}