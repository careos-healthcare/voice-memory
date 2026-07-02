/// Copy for the post-save return handoff after entry 1 or 2.
abstract final class PostSaveReturnHandoffCopy {
  PostSaveReturnHandoffCopy._();

  static const afterFirstSaveTitle = 'Come back when something similar happens';

  static const afterFirstSaveBodyFallback =
      'Record the second moment when something similar happens. ArchiveMe needs something to compare.';

  static const afterFirstSaveFooter =
      '1 of 3 · Ten seconds is enough.';

  static const afterSecondSaveRelatedTitle = 'One more unlocks first proof';

  static const afterSecondSaveRelatedBodyFallback =
      'Record one more related moment. ArchiveMe can show the repeat back to you.';

  static const afterSecondSaveRelatedFooter =
      '2 of 3 · Ten seconds is enough.';

  static const afterSecondSaveUnrelatedTitle = 'Keep recording real moments';

  static const afterSecondSaveUnrelatedBody =
      'No clear match yet — that is okay. Record the next real moment and ArchiveMe will keep looking.';

  static const afterSecondSaveUnrelatedFooter = 'No need to force a pattern.';

  static String afterFirstSaveBodyWithPhrase(String phrase) =>
      'Come back when something like “$phrase” happens and record it.';

  static String afterSecondSaveRelatedBodyWithPhrase(String phrase) =>
      'Record one more moment like “$phrase”. That unlocks your first proof.';
}
