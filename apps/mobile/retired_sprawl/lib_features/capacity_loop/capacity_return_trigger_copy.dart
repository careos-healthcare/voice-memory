/// Copy for capacity return trigger — calm, non-urgent language only.
abstract final class CapacityReturnTriggerCopy {
  CapacityReturnTriggerCopy._();

  static const activationTarget = 3;

  static const completionTitle = 'First moment saved.';
  static const completionBody =
      'Now wait for the next real one. Do not force it — come back when the '
      'pull shows up again.';
  static const completionPrimaryCta = 'Done for now';
  static const completionSecondaryCta = 'Save another';

  static String archiveHomeTitle(int saved) {
    if (saved == 1) return 'First moment saved.';
    if (saved == 2) return 'Two moments saved.';
    return 'Waiting for the next yes moment';
  }

  static String archiveHomeBody(int saved, {required int target}) {
    if (saved == 1) {
      return 'Now wait for the next real one. Do not force it — come back '
          'when the pull shows up again.';
    }
    if (saved == 2) {
      return 'One more real moment will make the pattern clearer.';
    }
    return 'You have $saved of $target saved. '
        'Come back when the next real request pulls you toward yes.';
  }

  static const archiveHomePrimaryCta = 'Done for now';

  static String archiveHomeSecondaryCta(int saved) {
    if (saved == 1) return 'Save another';
    if (saved == 2) return 'Save next yes moment';
    return 'Save next yes moment';
  }

  static const archiveHomeReviewCta = 'Review what I have';

  static const recordProgressLine =
      'Use this when a real yes moment happens again.';

  static const betaMissionHint = 'Come back when the next yes moment happens.';

  static const recordRoute = '/record';
  static const loopRoute = '/capacity-loop';

  static List<String> allVisibleStrings() => [
    completionTitle,
    completionBody,
    completionPrimaryCta,
    completionSecondaryCta,
    archiveHomeTitle(1),
    archiveHomeTitle(2),
    archiveHomeBody(1, target: activationTarget),
    archiveHomeBody(2, target: activationTarget),
    archiveHomePrimaryCta,
    archiveHomeSecondaryCta(1),
    archiveHomeSecondaryCta(2),
    archiveHomeReviewCta,
    recordProgressLine,
    betaMissionHint,
  ];
}
