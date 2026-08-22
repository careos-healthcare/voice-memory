/// Progressive evidence states — cautious, entry-count based.
abstract final class ProgressiveEvidenceStateCopy {
  ProgressiveEvidenceStateCopy._();

  static const zeroTitle = 'Record one real moment.';
  static const oneTitle = 'You started your archive.';
  static const twoTitle = 'ArchiveMe can compare.';
  static const threePlusTitle = 'First thread can appear.';

  static const zeroBody =
      'When something like it happens again, ArchiveMe will show what returned, '
      'changed, faded, or corrected.';
  static const oneBody =
      'One moment is saved. A second similar moment gives ArchiveMe something to compare.';
  static const twoBody =
      'Two moments are in. One more related moment may let the first thread appear.';
  static const threePlusBody =
      'Around three real moments, ArchiveMe can show what repeated — cautiously, not as a guarantee.';

  static const archiveOpensAt = 5;
  static const richerDiscoverAt = 21;

  static String titleForCount(int entryCount) {
    if (entryCount <= 0) return zeroTitle;
    if (entryCount == 1) return oneTitle;
    if (entryCount == 2) return twoTitle;
    return threePlusTitle;
  }

  static String bodyForCount(int entryCount) {
    if (entryCount <= 0) return zeroBody;
    if (entryCount == 1) return oneBody;
    if (entryCount == 2) return twoBody;
    return threePlusBody;
  }
}