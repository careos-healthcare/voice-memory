import '../post_save/post_save_focused_actions_copy.dart';

/// Exact Archive tab copy for the four early entry-count states.
abstract final class ArchiveTabFourStateCopy {
  ArchiveTabFourStateCopy._();

  static const emptyBody =
      'Nothing saved yet. Save one real moment first. '
      'ArchiveMe needs your words before it can compare anything.';

  static const oneBody =
      'Your archive has started. ArchiveMe needs another real moment '
      'before it can compare what repeats. Come back when this shows up again. '
      'You do not need to keep working on this now.';

  static const twoUnrelatedBody =
      'ArchiveMe has two moments to compare. No clear repeat yet. '
      'One more moment will make the thread easier to see.';

  static const twoRelatedLead =
      'Something came back. ArchiveMe found a pattern across your saved moments.';

  static const viewEvidenceCta = PostSaveFocusedActionsCopy.viewEvidence;

  static const recordMomentCta = 'Record a moment';

  static String twoRelatedBody({
    required String thread,
    required String change,
  }) =>
      "$twoRelatedLead This may connect to: '$thread'. What changed: $change.";
}
