/// Copy for post-save repeat intensity check — user-reported, not engine inferred.
abstract final class RepeatReturnCheckCopy {
  RepeatReturnCheckCopy._();

  static const prompt = 'Did this feel different from last time?';

  static const stronger = 'Stronger';
  static const same = 'About the same';
  static const softer = 'Softer';

  static const saved =
      'Saved. ArchiveMe will use this to track whether the repeat is changing.';

  static const dismiss = 'Dismiss';

  static const trendGettingLouder = 'The repeat is getting louder.';
  static const trendSofterThanBefore = 'The repeat is softer than before.';
  static const trendSteady = 'The repeat feels about the same as last time.';

  static const changeProofTitle = 'This is changing over time.';

  static const changeProofSupportLine =
      'Each return check helps ArchiveMe see whether this pattern is changing.';

  static const changeProofRecordNextCta = 'Record the next time it happens';
}
