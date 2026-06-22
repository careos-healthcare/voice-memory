/// Visible first-run / proof-layer copy — cautious, evidence-based.
abstract final class VisibleArchiveProofCopy {
  // Record screen top hero (zero entries).
  static const recordHeroTitle =
      'ArchiveMe notices what keeps repeating in your own words.';

  static const recordHeroBody =
      'Record one honest moment today. After a few moments, your archive '
      'can show what returned, what softened, and what changed.';

  static const recordHeroChipReturned = 'What returned';
  static const recordHeroChipSoftened = 'What softened';
  static const recordHeroChipChanged = 'What changed';

  // First save on Record screen.
  static const firstSaveTitle = 'Your archive has started.';

  static const firstSaveBody =
      'This is your first piece of evidence. Add one more moment and '
      'ArchiveMe can compare later.';

  static const firstSaveSecondary =
      'No conclusion yet — just one moment saved so far.';

  static const firstSavePrimaryCta = 'Add one more moment';
  static const firstSaveViewArchiveCta = 'View archive';

  // Patterns zero-entry preview.
  static const patternsEmptyPreviewTitle = 'What ArchiveMe will show over time';

  static const patternsEmptyPreviewBody =
      'Once you record a few moments, ArchiveMe compares your own words and '
      'shows what keeps returning, what changes, and the evidence behind it.';

  static const patternsEmptyPreviewBadge =
      'Preview — not a conclusion yet';

  static const patternsEmptyPreviewBeliefRow = 'Not enough evidence yet';
  static const patternsEmptyPreviewEvidenceRow =
      'Your own words across recordings';
  static const patternsEmptyPreviewChangedRow =
      'Whether the same thread gets lighter, stronger, or disappears';

  static const patternsEmptyPreviewCta = 'Record one moment';

  // Patterns one-entry state.
  static const patternsOneEntryTitle =
      'Your archive has one piece of evidence.';

  static const patternsOneEntryBody =
      'Add one more moment and ArchiveMe can start comparing your own words.';

  static const patternsOneEntryBeliefRow = 'Not enough evidence yet';
  static const patternsOneEntryEvidenceRow = '1 saved moment';
  static const patternsOneEntryChangedRow =
      'A second moment can show whether the same thread returns.';

  static const patternsOneEntryCta = 'Add one more moment';

  // Early repeat / two-entry payoff (cautious).
  static const earlyRepeatTitle =
      'ArchiveMe is starting to compare your moments.';

  static const earlyRepeatBody =
      'If the same words or situations keep returning, this is where your '
      'archive will show the thread.';

  static const earlyRepeatEvidenceLine =
      'You now have more than one moment to compare.';

  static const earlyRepeatNextAction =
      'Record once more to strengthen the signal.';

  // Two-entry comparison payoff (second session).
  static const twoEntryCompareTitle =
      'ArchiveMe has two moments to compare.';

  static const twoEntryBodyUngrounded =
      'No clear repeat yet. One more moment will make the thread easier to see.';

  static const twoEntryBodyGrounded =
      'These two moments may be related. ArchiveMe is keeping the evidence '
      'separate until there is more to compare.';

  static const twoEntryPrimaryCta = firstSavePrimaryCta;

  static const twoEntryViewArchiveCta = firstSaveViewArchiveCta;

  static const twoEntryNextAction =
      'Add one more moment to make the thread clearer.';

  // Three-entry belief payoff (cautious, evidence-based).
  static const threeEntryBeliefTitle =
      'ArchiveMe is starting to form a belief.';

  static const threeEntryBeliefBodyIntro =
      'This is not a conclusion yet. It is the first version of what your '
      'archive can compare.';

  static const threeEntryBeliefBodySource =
      'ArchiveMe is using your saved words, not guessing.';

  static const threeEntryBeliefEvidenceLabel = 'Evidence from your archive';

  static const threeEntryBeliefEvidenceThin =
      'The evidence is still thin.';

  static const threeEntryBeliefEvidenceThinAction =
      'Add one more moment to make this clearer.';

  static const threeEntryBeliefPrimaryCta = firstSavePrimaryCta;

  static const threeEntryBeliefViewArchiveCta = firstSaveViewArchiveCta;

  // Four-plus entry belief update — cautious evolution hook.
  static const beliefUpdateTitle = 'Your archive updated its belief.';

  static const beliefUpdateBodyChanged =
      'Something shifted in your saved words.';

  static const beliefUpdateBodyStillBuilding =
      'Your archive is still building evidence.';

  static const beliefUpdateCurrentBeliefLabel = 'Current belief';

  static const beliefUpdateEvidenceLabel = 'Evidence';

  static const beliefUpdateWhatChangedLabel = 'What changed';

  static const beliefUpdateChangeNewContext =
      'This showed up in a new context.';

  static const beliefUpdateChangeDifferentWords =
      'The same feeling appeared again, but with different words.';

  static const beliefUpdateChangeEasierCompare =
      'The evidence is still thin, but it is becoming easier to compare.';

  static const beliefUpdateDefaultBelief =
      'Your archive is beginning to notice similar pressure across your '
      'saved moments.';

  static const beliefUpdateWorkBelief =
      'Your archive is beginning to associate this with pressure around work.';

  static const beliefUpdatePrimaryCta = firstSavePrimaryCta;

  static const beliefUpdateViewEvidenceCta = 'View evidence';

  // Belief evidence drilldown — proof trail behind belief updates.
  static const beliefEvidenceTrailTitle = 'Evidence behind this belief';

  static const beliefEvidenceNotConclusion = 'This is not a conclusion.';

  static const beliefEvidenceSourceLine =
      'ArchiveMe is using your saved words, not guessing.';

  static const beliefEvidenceInsufficientBody =
      'Your archive needs more moments before it can show an evidence trail.';

  static const beliefEvidenceCurrentBeliefLabel = 'Current belief';

  static const beliefEvidenceWhatChangedLabel = 'What changed';

  static const beliefEvidenceArchiveLabel = 'Evidence from your archive';

  static const beliefEvidenceStillUncertainLabel = 'Still uncertain';

  static const beliefEvidenceStillThin = 'The evidence is still thin.';

  static const beliefEvidenceAddNextLabel = 'Add one more moment';

  static const beliefEvidenceNextWhenThin =
      'Add one more distinct moment to make this belief clearer.';

  static const beliefEvidenceNextDefault =
      'Add another moment when this shows up again.';

  // Day-two / return loop — calm next-return framing (no streaks or pressure).
  static const returnLoopOneEntryBody =
      'Come back when this shows up again.';

  static const returnLoopTwoEntryBody =
      'One more moment can make the thread clearer.';

  static const returnLoopThreeEntryBody =
      'Your archive is starting a cautious belief. '
      'Add one more moment to strengthen the evidence.';

  static const returnLoopPrimaryCta = firstSavePrimaryCta;

  static const returnLoopViewArchiveCta = firstSaveViewArchiveCta;

  // One-entry post-save — evidence only, no loop/repeat claims yet.
  static const oneEntryAddedTodayLine = 'You added one piece today.';
  static const oneEntryArchiveLine =
      'ArchiveMe has one moment to compare later.';
  static const oneEntryTomorrowLine =
      'Tomorrow, check whether this shows up again.';
  static const oneEntryAddMoreInvite =
      'Add one more moment when it happens again.';
  static const oneEntryShareableLine =
      'I recorded one moment for my archive.';

  // Static empty belief proof rows (Archive/Patterns proof card).
  static const emptyProofBelief = patternsEmptyPreviewBeliefRow;
  static const emptyProofEvidence = patternsEmptyPreviewEvidenceRow;
  static const emptyProofChanged = patternsEmptyPreviewChangedRow;
}
