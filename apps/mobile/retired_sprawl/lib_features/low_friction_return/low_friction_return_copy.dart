import 'package:archiveme_mobile/features/low_friction_return/low_friction_return_model.dart';

/// Permission-first return prompts — no daily requirement, no streak pressure.
abstract final class LowFrictionReturnCopy {
  LowFrictionReturnCopy._();

  static const corePositioning =
      'You do not need to record every day. Save a moment when something stands out.';

  static const title = 'Nothing to say today?';

  static const body =
      'You do not need a perfect entry. Save one sentence, skip today, or come back when something stands out.';

  static const permissionLine =
      'ArchiveMe works best with real moments, not forced daily journaling.';

  static const recordAnythingReminder =
      'You can save a thought, decision, win, worry, memory, conversation, pressure, reaction, or random moment.';

  static const saveOneSentenceAction = 'Save one sentence';

  static const useTinyPromptAction = 'Use a tiny prompt';

  static const skipTodayAction = 'Skip today';

  static const afterPromptSelected =
      'Start with one sentence. You can stop there.';

  static const afterSkip =
      'Skipped for today. Come back when something stands out.';

  static String promptTextFor(LowFrictionReturnPromptType type) =>
      switch (type) {
        LowFrictionReturnPromptType.whatKeptComingBack =>
          'What kept coming back today?',
        LowFrictionReturnPromptType.whatFeltHeavier =>
          'What felt heavier than it should?',
        LowFrictionReturnPromptType.whatChanged =>
          'What changed since last time?',
        LowFrictionReturnPromptType.whatDidIAvoid => 'What did I avoid?',
        LowFrictionReturnPromptType.whatHelped => 'What helped a little?',
        LowFrictionReturnPromptType.whatNotToForget =>
          'What do I not want to forget?',
      };

  static List<String> allVisibleStrings() => [
    title,
    body,
    permissionLine,
    recordAnythingReminder,
    saveOneSentenceAction,
    useTinyPromptAction,
    skipTodayAction,
    afterPromptSelected,
    afterSkip,
    for (final prompt in LowFrictionReturnPromptType.all) promptTextFor(prompt),
  ];
}