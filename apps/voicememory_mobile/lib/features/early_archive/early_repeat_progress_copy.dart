/// Copy for the first-three recording retention loop on Record.
abstract final class EarlyRepeatProgressCopy {
  EarlyRepeatProgressCopy._();

  static const oneMomentTitle = 'One moment saved';
  static const oneMomentBody =
      'Come back when something similar happens again. The second moment helps ArchiveMe compare.';
  static const oneMomentProgress = '1 of 3 moments for first repeat proof';

  static const twoRelatedTitle = 'A repeat may be forming';
  static const twoRelatedBody =
      'One more related moment lets ArchiveMe check whether this is really repeating.';
  static const twoRelatedProgress = '2 of 3 moments for first repeat proof';

  static const twoUnrelatedTitle = 'Two moments saved';
  static const twoUnrelatedBody =
      'ArchiveMe has two moments, but they do not look clearly related yet. Record the next real moment and it will keep looking.';
  static const twoUnrelatedProgress = '2 moments saved';

  static const oneMomentCueLabel = 'Watch for this next';
  static const oneMomentCueBodyFallback =
      'Next time the same kind of moment happens again, record it. The second moment helps ArchiveMe compare.';
  static const oneMomentCueFooter = 'It only needs ten seconds.';

  static const twoRelatedCueLabel = 'Record one more like this';
  static const twoRelatedCueBodyFallback =
      'One more related moment lets ArchiveMe check whether this is really repeating.';
  static const twoRelatedCueFooter =
      'That third moment creates the first real proof.';

  static const twoUnrelatedCueLabel = 'Record the next real moment';
  static const twoUnrelatedCueBody =
      'These two moments do not clearly match yet. Record the next real moment and ArchiveMe will keep looking.';
  static const twoUnrelatedCueFooter = 'No need to force a pattern.';

  static String oneMomentCueBodyWithPhrase(String phrase) =>
      'Next time something like “$phrase” happens, record that moment. That gives ArchiveMe something to compare.';

  static String twoRelatedCueBodyWithPhrase(String phrase) =>
      'One more moment like “$phrase” lets ArchiveMe check whether this is really repeating.';
}
