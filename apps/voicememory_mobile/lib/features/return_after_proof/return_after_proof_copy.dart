import 'return_after_proof_model.dart';

/// Return-after-proof prompts — no streak pressure, no notifications.
abstract final class ReturnAfterProofCopy {
  ReturnAfterProofCopy._();

  static const title = 'What to watch for next';

  static const body =
      'ArchiveMe has enough to start a timeline. The next useful moment is whether this returns or changes.';

  static const strongBody =
      'ArchiveMe has a clearer timeline now. The next useful moment is whether this returns or changes.';

  static const closingLine = 'If nothing stands out, skip today.';

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

  static String chipLabelFor(ReturnAfterProofPromptType type) =>
      switch (type) {
        ReturnAfterProofPromptType.itCameBack => promptItCameBack,
        ReturnAfterProofPromptType.feltLighter => promptFeltLighter,
        ReturnAfterProofPromptType.feltHeavier => promptFeltHeavier,
        ReturnAfterProofPromptType.somethingHelped => promptSomethingHelped,
        ReturnAfterProofPromptType.handledDifferently =>
          promptHandledDifferently,
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

  static List<String> allVisibleStrings() => [
        title,
        body,
        strongBody,
        closingLine,
        afterNotTodayDismiss,
        for (final type in ReturnAfterProofPromptTypeLists.capturePrompts)
          chipLabelFor(type),
        for (final type in ReturnAfterProofPromptTypeLists.capturePrompts)
          selectedPromptLineFor(type),
        promptNotToday,
      ];
}
