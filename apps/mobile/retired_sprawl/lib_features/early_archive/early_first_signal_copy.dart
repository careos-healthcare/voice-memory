/// Early archive copy — first entries through confirmed-repeat follow-ups.
abstract final class EarlyFirstSignalCopy {
  static const notEnoughEvidence = 'Not enough evidence yet.';

  static const addMomentCta = 'Add one more moment';

  static const confirmRepeatCta = 'Add one more to confirm';

  static const recordSimilarMomentCta =
      'Record one more moment like this to confirm whether it repeats.';

  // One saved moment — ready state, not a pattern yet.
  static const oneEntryTitle = 'Add one more moment.';

  static const oneEntryBody =
      'ArchiveMe needs a second moment before it can compare what repeats.';

  // Two moments, no grounded repeat — do not force a pattern.
  static const twoEntryNoPatternTitle = 'Keep adding moments.';

  static const twoEntryNoPatternBody =
      'ArchiveMe has two pieces of evidence, but not enough to call a repeat yet.';

  // Two moments with a grounded repeat — cautious first signal only.
  static const twoEntryRelatedTitle =
      'One more will confirm whether this repeats.';

  static const twoEntryRelatedBody =
      'ArchiveMe has seen this twice. A third moment makes the pattern clearer.';

  /// Legacy alias — prefer [twoEntryRelatedTitle].
  static const String twoEntryPatternStartTitle = twoEntryRelatedTitle;

  /// Legacy alias — prefer [twoEntryRelatedBody].
  static const String twoEntryNoticedAgain = twoEntryRelatedBody;

  /// Legacy alias — prefer [confirmRepeatCta].
  static const String twoEntryConfirmRepeat = confirmRepeatCta;

  // Three related moments — grounded confirmation, still evidence-led.
  static const threeEntryConfirmedTitle = 'This is now a confirmed repeat.';

  static const threeEntrySeenThreeTimes =
      'ArchiveMe found this repeat across 3 moments in your words.';

  static const evidenceHeading = 'Evidence from your words:';

  static const evidenceSupportLine =
      'That is why your archive is tracking this repeat.';

  static const threeEntryFormingTitle = 'A repeat may be forming.';

  static const threeEntryFormingBody =
      'ArchiveMe needs one more concrete moment before it names this clearly.';

  static const threeEntryNeedsMoreBody =
      'ArchiveMe has seen a possible repeat, but it needs one more specific '
      'moment before naming it clearly.';

  /// Legacy alias — prefer [evidenceHeading].
  static const legacyEvidenceHeading = "Here's the evidence.";

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

  // Payoff after saving from the confirmed-repeat trigger prompt.
  static const triggerPayoffTitle =
      'Now your archive has the repeat and the trigger.';

  static const triggerPayoffBody =
      'You recorded what happened right before it. That gives ArchiveMe '
      'stronger evidence for what starts this loop.';

  static const triggerPayoffRepeatEvidence = 'Repeat: seen across 3 moments.';

  static const triggerPayoffTriggerEvidence = 'Trigger: captured once.';

  static const triggerPayoffPrimaryCta = 'Keep watching this';

  // After a confirmed repeat returns with softening language in a later entry.
  static const changeNoticeTitle = 'Something changed this time.';

  static const changeNoticeBody =
      'The same loop came back, but your archive noticed it may have been softer.';

  static const changeNoticeRepeatEvidence = 'Repeat: already confirmed.';

  static const changeNoticeChangeEvidence =
      'Change: this entry sounded less urgent.';

  static const recordWhatHelpedCta = 'Record what helped';

  static const recordWhatHelpedGuidedPrompt =
      'What helped you handle it differently this time?';

  // Payoff after saving from the helpful-action guided prompt.
  static const helpfulActionPayoffTitle =
      'ArchiveMe captured helpful evidence.';

  static const helpfulActionPayoffBody =
      'You mentioned something that may have softened the loop. Your archive is watching whether it shows up again.';

  static const helpfulActionRepeatEvidence = 'Repeat: already confirmed.';

  static const helpfulActionChangeEvidence = 'Change: sounded softer once.';

  static const helpfulActionCapturedEvidence = 'Helpful action: captured once.';
}