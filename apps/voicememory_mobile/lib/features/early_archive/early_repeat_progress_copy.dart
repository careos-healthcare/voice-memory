/// Copy for the first-three recording retention loop on Record.
abstract final class EarlyRepeatProgressCopy {
  EarlyRepeatProgressCopy._();

  static const oneMomentTitle = 'One moment saved';
  static const oneMomentBody =
      'Come back when something similar happens. Short is fine.';
  static const oneMomentProgress = '1 of 3';

  static const twoRelatedTitle = 'Two similar moments';
  static const twoRelatedBody =
      'One more related moment unlocks your first proof.';
  static const twoRelatedProgress = '2 of 3';

  static const twoUnrelatedTitle = 'Two moments saved';
  static const twoUnrelatedBody =
      'No clear match yet — that is okay. Record the next real moment.';
  static const twoUnrelatedProgress = '2 of 3';

  static const oneMomentCueLabel = 'Next step';
  static const oneMomentCueBodyFallback =
      'Come back when something similar happens.';
  static const oneMomentCueFooter = 'Ten seconds is enough.';

  static const twoRelatedCueLabel = 'One more unlocks first proof';
  static const twoRelatedCueBodyFallback =
      'Record when something similar happens again.';
  static const twoRelatedCueFooter = 'That creates your first proof.';

  static const twoUnrelatedCueLabel = 'Next step';
  static const twoUnrelatedCueBody =
      'Record the next real moment. ArchiveMe will keep looking.';
  static const twoUnrelatedCueFooter = 'No need to force a pattern.';

  static String oneMomentCueBodyWithPhrase(String phrase) =>
      'Come back when something like “$phrase” happens and record it.';

  static String twoRelatedCueBodyWithPhrase(String phrase) =>
      'Record one more moment like “$phrase”. That unlocks your first proof.';
}
