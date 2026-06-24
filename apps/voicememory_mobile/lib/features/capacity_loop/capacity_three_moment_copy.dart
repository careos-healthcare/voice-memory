/// Copy for capacity 3-moment activation — safe, non-clinical language.
abstract final class CapacityThreeMomentCopy {
  CapacityThreeMomentCopy._();

  static const activationPromise =
      'Save 3 yes moments. See what keeps repeating.';

  static const cardTitle = 'Your first 3 yes moments';
  static const cardSubtitle =
      'Save three real moments where you felt pulled to say yes.';

  static const emptyBody =
      'Start with one real moment. One useful moment is enough.';

  static const saveYesMomentCta = 'Save yes moment';
  static const reviewLoopCta = 'Review your yes loop';

  static const recordRoute = '/record';
  static const loopRoute = '/capacity-loop';

  static String progressLabel(int saved, {required int target}) {
    if (saved <= 0) return '0 of $target saved';
    if (saved >= target) {
      return '$target of $target saved — review your yes loop';
    }
    return '$saved of $target saved';
  }

  static String recordProgressLine(int saved, {required int target}) =>
      'Capacity path: $saved of $target yes moments saved';

  static const loopGuidanceTitle = 'Build your first 3 yes moments';
  static const loopGuidanceBody =
      'Save three real moments where you felt pulled to say yes. Then review what may be repeating.';

  static const betaTaskLine =
      'Beta task: save 3 real yes moments, then review your loop.';

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
