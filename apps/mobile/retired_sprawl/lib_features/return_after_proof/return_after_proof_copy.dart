import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_model.dart';

/// Return-after-proof prompts — no streak pressure, no notifications.
abstract final class ReturnAfterProofCopy {
  ReturnAfterProofCopy._();

  static const title = 'What to watch for next';

  static const body =
      'ArchiveMe has enough to start a timeline. The next useful moment is whether this returns or changes.';

  static const strongBody =
      'ArchiveMe has a clearer timeline now. The next useful moment is whether this returns or changes.';

  static const closingLine = 'If nothing stands out, skip today.';

  static const strengthenedTitle = 'Watch one thing next';

  static const strengthenedPrimaryCta = 'Save if it happens';

  static const strengthenedSecondaryCta = 'Not today';

  static const repeatWatchBody =
      'Next time this comes back, save what was different.';

  static const softeningWatchBody =
      'Next time it feels lighter, save what helped.';

  static const strengtheningWatchBody =
      'Next time it feels stronger, save what made it sharper.';

  static const helpedWatchBody = 'Next time something helps, save the detail.';

  static const correctedWatchBody =
      'If this becomes relevant again, save the return.';

  static const fallbackWatchBody = 'Come back when this returns or changes.';

  static const promptReturnedAgain =
      'This came back, and what was different was:';

  static const promptFeltLighterBecause = 'This felt lighter because:';

  static const promptFeltHeavierBecause = 'This felt heavier because:';

  static const promptHelpedAgain = 'What helped was:';

  static const promptHandledDifferentlyBy = 'I handled this differently by:';

  static const promptAvoidedAgain = 'I avoided this by:';

  static const promptNotCurrentBecause = 'This is not current because:';

  static const afterNotTodayDismiss =
      'Okay. Come back when something stands out.';

  static const promptItCameBack = 'It came back';
  static const promptFeltLighter = 'It felt lighter';
  static const promptFeltHeavier = 'It felt heavier';
  static const promptSomethingHelped = 'Something helped';
  static const promptHandledDifferently = 'I handled it differently';
  static const promptNotToday = 'Not today';

  static const selectedItCameBack = 'This came back:';
  static const selectedFeltLighter = 'This felt lighter:';
  static const selectedFeltHeavier = 'This felt heavier:';
  static const selectedSomethingHelped = 'Something helped:';
  static const selectedHandledDifferently = 'I handled this differently:';

  static String chipLabelFor(ReturnAfterProofPromptType type) => switch (type) {
    ReturnAfterProofPromptType.itCameBack => promptItCameBack,
    ReturnAfterProofPromptType.feltLighter => promptFeltLighter,
    ReturnAfterProofPromptType.feltHeavier => promptFeltHeavier,
    ReturnAfterProofPromptType.somethingHelped => promptSomethingHelped,
    ReturnAfterProofPromptType.handledDifferently => promptHandledDifferently,
    ReturnAfterProofPromptType.notToday => promptNotToday,
  };

  static String selectedPromptLineFor(ReturnAfterProofPromptType type) =>
      switch (type) {
        ReturnAfterProofPromptType.itCameBack => selectedItCameBack,
        ReturnAfterProofPromptType.feltLighter => selectedFeltLighter,
        ReturnAfterProofPromptType.feltHeavier => selectedFeltHeavier,
        ReturnAfterProofPromptType.somethingHelped => selectedSomethingHelped,
        ReturnAfterProofPromptType.handledDifferently =>
          selectedHandledDifferently,
        ReturnAfterProofPromptType.notToday => afterNotTodayDismiss,
      };

  static String bodyForWatchTarget(ReturnAfterProofWatchTargetType type) =>
      switch (type) {
        ReturnAfterProofWatchTargetType.returnedAgain => repeatWatchBody,
        ReturnAfterProofWatchTargetType.feltLighter => softeningWatchBody,
        ReturnAfterProofWatchTargetType.feltHeavier => strengtheningWatchBody,
        ReturnAfterProofWatchTargetType.helpedAgain => helpedWatchBody,
        ReturnAfterProofWatchTargetType.handledDifferently => repeatWatchBody,
        ReturnAfterProofWatchTargetType.avoidedAgain => repeatWatchBody,
        ReturnAfterProofWatchTargetType.notCurrent => correctedWatchBody,
      };

  static String promptLineForWatchTarget(
    ReturnAfterProofWatchTargetType type,
  ) => switch (type) {
    ReturnAfterProofWatchTargetType.returnedAgain => promptReturnedAgain,
    ReturnAfterProofWatchTargetType.feltLighter => promptFeltLighterBecause,
    ReturnAfterProofWatchTargetType.feltHeavier => promptFeltHeavierBecause,
    ReturnAfterProofWatchTargetType.helpedAgain => promptHelpedAgain,
    ReturnAfterProofWatchTargetType.handledDifferently =>
      promptHandledDifferentlyBy,
    ReturnAfterProofWatchTargetType.avoidedAgain => promptAvoidedAgain,
    ReturnAfterProofWatchTargetType.notCurrent => promptNotCurrentBecause,
  };

  static List<String> allVisibleStrings() => [
    title,
    body,
    strongBody,
    closingLine,
    strengthenedTitle,
    strengthenedPrimaryCta,
    strengthenedSecondaryCta,
    repeatWatchBody,
    softeningWatchBody,
    strengtheningWatchBody,
    helpedWatchBody,
    correctedWatchBody,
    fallbackWatchBody,
    promptReturnedAgain,
    promptFeltLighterBecause,
    promptFeltHeavierBecause,
    promptHelpedAgain,
    promptHandledDifferentlyBy,
    promptAvoidedAgain,
    promptNotCurrentBecause,
    afterNotTodayDismiss,
    for (final type in ReturnAfterProofPromptTypeLists.capturePrompts)
      chipLabelFor(type),
    for (final type in ReturnAfterProofPromptTypeLists.capturePrompts)
      selectedPromptLineFor(type),
    promptNotToday,
  ];
}