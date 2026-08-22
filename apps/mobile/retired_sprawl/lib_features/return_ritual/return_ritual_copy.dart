import 'package:archiveme_mobile/features/return_ritual/return_ritual_models.dart';

/// User-facing copy for the personal return ritual — no streaks or pressure.
abstract final class ReturnRitualCopy {
  ReturnRitualCopy._();

  static const chooseTitle = 'Choose your return ritual';
  static const chooseBody =
      'ArchiveMe gets more useful when you return at the moment a pattern is happening again.';

  static const savedTitle = 'Your return ritual';
  static const savedComeBackPrefix = 'Come back when:';
  static const savedBodyDefault = 'Come back when this happens again.';
  static const savedBodyBeliefFits =
      'Use this ritual to test whether the belief still fits.';
  static const savedBodyWeeklyReview =
      "Use this ritual to strengthen next week's review.";

  static const privacyLine = 'This stays on this device.';

  static const changeButton = 'Change';
  static const addMomentButton = 'Add a moment';
  static const clearButton = 'Clear ritual';
  static const customPhraseButton = 'Custom phrase';
  static const customPhraseSheetTitle = 'Your return phrase';
  static const customPhraseHint = 'When will ArchiveMe help most?';
  static const customPhraseSave = 'Save phrase';
  static const customPhraseCancel = 'Cancel';

  static const presetUnclearDecision = ReturnRitualPreset(
    id: 'unclear_decision',
    phrase: 'When a decision feels unclear',
  );
  static const presetEndWorkday = ReturnRitualPreset(
    id: 'end_workday',
    phrase: 'At the end of the workday',
  );
  static const presetSameThought = ReturnRitualPreset(
    id: 'same_thought',
    phrase: 'When I notice the same thought again',
  );
  static const presetBeforeSleep = ReturnRitualPreset(
    id: 'before_sleep',
    phrase: 'Before I sleep',
  );
  static const presetLoudFeeling = ReturnRitualPreset(
    id: 'loud_feeling',
    phrase: 'After something feels loud',
  );

  static const presets = <ReturnRitualPreset>[
    presetUnclearDecision,
    presetEndWorkday,
    presetSameThought,
    presetBeforeSleep,
    presetLoudFeeling,
  ];

  static String savedBodyForEntryCount(int entryCount) {
    if (entryCount >= 5) return savedBodyWeeklyReview;
    if (entryCount >= 3) return savedBodyBeliefFits;
    return savedBodyDefault;
  }

  static String savedComeBackLine(String phrase) =>
      '$savedComeBackPrefix $phrase';
}