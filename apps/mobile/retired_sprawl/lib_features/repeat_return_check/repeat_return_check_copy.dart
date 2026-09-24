/// Copy for post-save repeat intensity check — user-reported, not engine inferred.
abstract final class RepeatReturnCheckCopy {
  RepeatReturnCheckCopy._();

  static const prompt = 'Did this feel different from last time?';

  static const stronger = 'Stronger';
  static const same = 'About the same';
  static const softer = 'Softer';
  static const changed = 'Different';

  static const saved =
      'Saved. ArchiveMe will use this to track whether the repeat is changing.';

  static const dismiss = 'Dismiss';

  static const trendGettingLouder = 'Stronger since your first proof.';
  static const trendSofterThanBefore = 'Softer since your first proof.';
  static const trendSteady = 'About the same since your first proof.';

  static const changeProofTitle = 'What changed over time';

  static const changeProofSupportLine =
      'Each return helps ArchiveMe compare what changed since your first proof.';

  static const changeProofRecordNextCta = 'Record the next time it happens';
}
