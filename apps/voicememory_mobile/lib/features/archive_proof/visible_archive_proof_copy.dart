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
