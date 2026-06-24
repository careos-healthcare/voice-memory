/// Copy for capacity return trigger — calm, non-urgent language only.
abstract final class CapacityReturnTriggerCopy {
  CapacityReturnTriggerCopy._();

  static const activationTarget = 3;

  static const completionTitle = 'Next time this happens';
  static const completionBody =
      'When you feel pulled to say yes again, save that moment too. '
      'Three real moments are enough to start seeing what repeats.';
  static const completionPrimaryCta = 'Save another yes moment';
  static const completionSecondaryCta = 'Done for now';

  static const archiveHomeTitle = 'Come back for the next yes moment';
  static String archiveHomeBody(int saved, {required int target}) =>
      'You have $saved of $target yes moments saved. '
      'The next real moment will make your yes loop clearer.';

  static const archiveHomePrimaryCta = 'Save yes moment';
  static const archiveHomeReviewCta = 'Review what I have';

  static const recordProgressLine =
      'Next goal: save the next real yes moment.';

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
