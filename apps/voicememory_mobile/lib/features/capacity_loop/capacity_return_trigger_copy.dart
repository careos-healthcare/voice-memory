/// Copy for capacity return trigger — calm, non-urgent language only.
abstract final class CapacityReturnTriggerCopy {
  CapacityReturnTriggerCopy._();

  static const activationTarget = 3;

  static const completionTitle =
      'Good — now wait for the next real yes moment';
  static const completionBody =
      'Do not force another entry. Come back when you feel the pull to agree again. '
      'That second moment is what starts making the pattern clearer.';
  static const completionPrimaryCta = 'Done for now';
  static const completionSecondaryCta = 'Save another yes moment';

  static const archiveHomeTitle = 'Waiting for the next yes moment';
  static String archiveHomeBody(int saved, {required int target}) =>
      'You have $saved of $target saved. '
      'Come back when the next real request pulls you toward yes.';

  static const archiveHomePrimaryCta = 'Save yes moment';
  static const archiveHomeReviewCta = 'Review what I have';

  static const recordProgressLine =
      'Use this when a real yes moment happens again.';

  static const betaMissionHint =
      'Come back when the next yes moment happens.';

  static const recordRoute = '/record';
  static const loopRoute = '/capacity-loop';

  static List<String> allVisibleStrings() => [
        completionTitle,
        completionBody,
        completionPrimaryCta,
        completionSecondaryCta,
        archiveHomeTitle,
        archiveHomeBody(1, target: activationTarget),
        archiveHomeBody(2, target: activationTarget),
        archiveHomePrimaryCta,
        archiveHomeReviewCta,
        recordProgressLine,
        betaMissionHint,
      ];
}
