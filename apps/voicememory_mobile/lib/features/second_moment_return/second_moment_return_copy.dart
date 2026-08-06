import 'second_moment_return_model.dart';

import '../three_moment_activation/three_moment_activation_copy.dart';

/// Second-moment return copy — one reason to come back, no daily pressure.
abstract final class SecondMomentReturnCopy {
  SecondMomentReturnCopy._();

  static const coreReturnReason =
      'Come back when something repeats, changes, or feels different.';

  static const title = 'Come back when something stands out';

  static const bodyStart = ThreeMomentActivationCopy.momentOneLine;

  static const bodyCompare = ThreeMomentActivationCopy.momentTwoLine;

  static const bodyThird = ThreeMomentActivationCopy.momentThreeLine;

  static const body = '$bodyStart $bodyCompare $bodyThird';

  static const noticeLine =
      'Watch for what repeats, changes, feels lighter, feels heavier, or helps a little.';

  static const noPressureLine = 'You do not need to record every day.';

  static const noticedSomethingAction = 'I noticed something';

  static const showWhatToNoticeAction = 'Show me what to notice';

  static const notTodayAction = 'Not today';

  static const afterNoticedSomething =
      'Save one sentence about what stood out.';

  static const afterNotToday = 'Okay. Come back when something stands out.';

  static const didThisComeBackPrompt = 'Did this come back?';
  static const didItFeelDifferentPrompt = 'Did it feel different?';
  static const didAnythingHelpPrompt = 'Did anything help?';
  static const didYouAvoidItAgainPrompt = 'Did you avoid it again?';
  static const didSomethingFeelHeavierPrompt =
      'Did something feel heavier than expected?';

  static const promptOrder = [
    SecondMomentReturnPromptType.didThisComeBack,
    SecondMomentReturnPromptType.didItFeelDifferent,
    SecondMomentReturnPromptType.didAnythingHelp,
    SecondMomentReturnPromptType.didYouAvoidItAgain,
    SecondMomentReturnPromptType.didSomethingFeelHeavier,
  ];

  static String promptTextFor(
    SecondMomentReturnPromptType type,
  ) => switch (type) {
    SecondMomentReturnPromptType.didThisComeBack => didThisComeBackPrompt,
    SecondMomentReturnPromptType.didItFeelDifferent => didItFeelDifferentPrompt,
    SecondMomentReturnPromptType.didAnythingHelp => didAnythingHelpPrompt,
    SecondMomentReturnPromptType.didYouAvoidItAgain => didYouAvoidItAgainPrompt,
    SecondMomentReturnPromptType.didSomethingFeelHeavier =>
      didSomethingFeelHeavierPrompt,
  };

  static List<String> allVisibleStrings() => [
    coreReturnReason,
    title,
    bodyStart,
    bodyCompare,
    bodyThird,
    body,
    noticeLine,
    noPressureLine,
    noticedSomethingAction,
    showWhatToNoticeAction,
    notTodayAction,
    afterNoticedSomething,
    afterNotToday,
    didThisComeBackPrompt,
    didItFeelDifferentPrompt,
    didAnythingHelpPrompt,
    didYouAvoidItAgainPrompt,
    didSomethingFeelHeavierPrompt,
  ];
}
