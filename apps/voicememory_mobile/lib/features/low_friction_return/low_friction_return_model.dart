/// Lightweight tiny-prompt types — prompt context only, no classification.
enum LowFrictionReturnPromptType {
  whatKeptComingBack,
  whatFeltHeavier,
  whatChanged,
  whatDidIAvoid,
  whatHelped,
  whatNotToForget;

  String get analyticsValue => switch (this) {
    whatKeptComingBack => 'what_kept_coming_back',
    whatFeltHeavier => 'what_felt_heavier',
    whatChanged => 'what_changed',
    whatDidIAvoid => 'what_did_i_avoid',
    whatHelped => 'what_helped',
    whatNotToForget => 'what_not_to_forget',
  };

  static const all = [
    whatKeptComingBack,
    whatFeltHeavier,
    whatChanged,
    whatDidIAvoid,
    whatHelped,
    whatNotToForget,
  ];
}

enum LowFrictionReturnActionType {
  saveOneSentence,
  useTinyPrompt,
  skipToday;

  String get analyticsValue => switch (this) {
    saveOneSentence => 'save_one_sentence',
    useTinyPrompt => 'use_tiny_prompt',
    skipToday => 'skip_today',
  };
}
