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
}
