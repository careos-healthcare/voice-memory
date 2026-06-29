/// Early archive copy — 1–3 entries, before a belief is earned.
abstract final class EarlyFirstSignalCopy {
  static const notEnoughEvidence = 'Not enough evidence yet.';

  static const addMomentCta = 'Add one more moment';

  static const recordSimilarMomentCta =
      'Record one more moment like this to confirm whether it repeats.';

  // One saved moment — heard, not a pattern.
  static const oneEntryTitle = 'ArchiveMe heard this moment.';

  static const oneEntryBody =
      'Your first moment is saved. There is not a pattern yet — just one '
      'piece of evidence from your own words.';

  // Two moments, no grounded repeat — do not force a pattern.
  static const twoEntryNoPatternTitle = 'Two moments saved.';

  static const twoEntryNoPatternBody =
      'No clear repeat yet. One more moment will make it easier to see '
      'whether the same thread returns.';

  // Two moments with a grounded repeat — cautious first signal only.
  static const twoEntryPatternStartTitle =
      'This may be the start of a pattern.';

  static const twoEntryNoticedAgain =
      'ArchiveMe noticed this came up again.';

  static const twoEntryConfirmRepeat =
      'Record one more moment like this to confirm whether it repeats.';

  // Three related moments — grounded confirmation, still evidence-led.
  static const threeEntryConfirmedTitle = 'This is now a confirmed repeat.';

  static const threeEntrySeenThreeTimes =
      'ArchiveMe has seen this come back across 3 moments.';

  static const evidenceHeading = "Here's the evidence.";

  static const recordWhatHappensNextCta = 'Record what happens next';

  static const viewEvidenceCta = 'View evidence';

  // After a confirmed 3-entry repeat — one specific next observation.
  static const returnPromptTitle = 'Watch for what happens right before this.';

  static const returnPromptBody =
      'Next time it comes up, record the trigger, not just the feeling.';

  static const recordTriggerNextTimeCta = 'Record the trigger next time';

  /// Prefilled Record prompt when the user taps the return CTA.
  static const recordTriggerGuidedPrompt =
      'What happened right before this came up?';
}
