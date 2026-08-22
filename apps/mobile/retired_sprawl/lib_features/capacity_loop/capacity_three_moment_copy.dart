/// Copy for capacity 3-moment activation — safe, non-clinical language.
abstract final class CapacityThreeMomentCopy {
  CapacityThreeMomentCopy._();

  static const activationPromise = 'Save 3 yes moments. See what returned.';

  static const cardTitle = 'Save 3 yes moments';
  static const cardSubtitle =
      'Three real moments are enough to start seeing what repeats.';

  static const emptyBody =
      'Start with one real moment. One useful moment is enough.';

  static const saveYesMomentCta = 'Save yes moment';
  static const reviewLoopCta = 'Review your yes loop';

  static const recordRoute = '/record';
  static const loopRoute = '/capacity-loop';

  static String progressLabel(int saved, {required int target}) {
    if (saved <= 0) return '0 of $target yes moments saved';
    if (saved >= target) {
      return '$target of $target yes moments saved — review your yes loop';
    }
    return '$saved of $target yes moments saved';
  }

  static String recordProgressLine(int saved, {required int target}) =>
      progressLabel(saved, target: target);

  static const loopGuidanceTitle = 'Save 3 yes moments';
  static const loopGuidanceBody =
      'Three real moments are enough to start seeing what repeats.';

  static const betaTaskLine =
      'Beta task: save 3 real moments when something stands out, then see what returned.';

  static List<String> allVisibleStrings() => [
    activationPromise,
    cardTitle,
    cardSubtitle,
    emptyBody,
    saveYesMomentCta,
    reviewLoopCta,
    progressLabel(0, target: 3),
    progressLabel(1, target: 3),
    progressLabel(2, target: 3),
    progressLabel(3, target: 3),
    recordProgressLine(1, target: 3),
    loopGuidanceTitle,
    loopGuidanceBody,
    betaTaskLine,
  ];
}