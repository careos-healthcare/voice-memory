/// Copy for the post-save return handoff after entry 1 or 2.
abstract final class PostSaveReturnHandoffCopy {
  PostSaveReturnHandoffCopy._();

  static const afterFirstSaveTitle = 'Come back when this happens again';

  static const afterFirstSaveBodyFallback =
      'Next time the same kind of moment happens again, record it. That second moment gives ArchiveMe something to compare.';

  static const afterFirstSaveFooter =
      'Short is fine — ten seconds is enough.';

  static const afterSecondSaveRelatedTitle = 'One more creates the first proof';

  static const afterSecondSaveRelatedBodyFallback =
      'One more related moment lets ArchiveMe check whether this is really repeating.';

  static const afterSecondSaveRelatedFooter =
      'The third moment is where ArchiveMe can show the pattern back to you.';

  static const afterSecondSaveUnrelatedTitle = 'Keep recording real moments';

  static const afterSecondSaveUnrelatedBody =
      'These two moments do not clearly match yet. Record the next real moment and ArchiveMe will keep looking.';

  static const afterSecondSaveUnrelatedFooter = 'No need to force a pattern.';

  static String afterFirstSaveBodyWithPhrase(String phrase) =>
      'Next time something like “$phrase” happens, record that moment. That second moment gives ArchiveMe something to compare.';

  static String afterSecondSaveRelatedBodyWithPhrase(String phrase) =>
      'One more moment like “$phrase” lets ArchiveMe check whether this is really repeating.';
}
