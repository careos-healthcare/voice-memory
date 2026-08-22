/// Copy for the unified three-moment completion guidance card.
abstract final class ThreeMomentCompletionCopy {
  ThreeMomentCompletionCopy._();

  static const noPressureLine = 'No daily journal required.';

  static const secondaryCta = 'Not today';

  static const startTitle = 'Start with one sentence';
  static const startBody = 'Anything from today counts.';
  static const startPrimaryCta = 'Save one sentence';

  static const secondTitle = 'Add one more moment when something stands out';
  static const secondBody =
      'A second moment gives ArchiveMe something to compare.';
  static const secondPrimaryCta = 'I noticed something';

  static const thirdTitle = 'One more moment can reveal what returned';
  static const thirdBody =
      'A third real moment can help ArchiveMe show whether something returned.';
  static const thirdPrimaryCta = 'Save one more moment';

  static Iterable<String> allVisibleStrings() sync* {
    yield startTitle;
    yield startBody;
    yield secondTitle;
    yield secondBody;
    yield thirdTitle;
    yield thirdBody;
    yield noPressureLine;
    yield startPrimaryCta;
    yield secondPrimaryCta;
    yield thirdPrimaryCta;
    yield secondaryCta;
  }
}