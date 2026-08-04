import 'cognitive_metrics_models.dart';

final class BurnoutDetector {
  const BurnoutDetector({
    this.negativeValenceThreshold = -.2,
    this.negativeClusterThreshold = .4,
    this.stalledHabitThreshold = .4,
  });

  final double negativeValenceThreshold;
  final double negativeClusterThreshold;
  final double stalledHabitThreshold;

  BurnoutAdvisory? evaluate(List<CognitiveMetricPoint> points) {
    if (points.length < 3) return null;
    final recent = points.sublist(points.length - 3);
    if (!_consecutive(recent)) return null;
    final persistentNegative = recent.every(
      (point) =>
          (point.movingAverage7 ?? point.valence ?? 0) <=
              negativeValenceThreshold &&
          point.negativeClusterDensity >= negativeClusterThreshold,
    );
    final decliningSleep =
        recent.every((point) => point.sleepHours != null) &&
        recent[0].sleepHours! > recent[1].sleepHours! &&
        recent[1].sleepHours! > recent[2].sleepHours! &&
        recent.last.sleepHours! < 7;
    final stalledHabits =
        recent.last.habitMomentum <= stalledHabitThreshold &&
        recent[0].habitMomentum >= recent[1].habitMomentum &&
        recent[1].habitMomentum >= recent[2].habitMomentum;
    final highLoad = recent.every((point) => point.cognitiveLoad >= .7);
    final reasons = <String>[
      if (persistentNegative)
        'Difficult emotional signals persisted for 3 days.',
      if (decliningSleep)
        'Local sleep readings declined across the same period.',
      if (stalledHabits) 'Habit momentum remained low or moved downward.',
      if (highLoad) 'Open cognitive loops remained densely concentrated.',
    ];
    if (persistentNegative && decliningSleep && stalledHabits) {
      return BurnoutAdvisory(
        level: BurnoutRiskLevel.elevated,
        title: 'A gentler pace may help',
        message:
            'Several local signals have moved together for three days. This is '
            'not a diagnosis. Consider protecting recovery time, reducing one '
            'nonessential commitment, or reflecting with the Cognitive Council.',
        reasons: List.unmodifiable(reasons),
      );
    }
    if ((persistentNegative && (stalledHabits || highLoad)) ||
        (decliningSleep && highLoad)) {
      return BurnoutAdvisory(
        level: BurnoutRiskLevel.watch,
        title: 'Check in with your capacity',
        message:
            'A few local patterns suggest that extra recovery space may be '
            'useful. Consider a short rest protocol and reassess tomorrow.',
        reasons: List.unmodifiable(reasons),
      );
    }
    return null;
  }

  static bool _consecutive(List<CognitiveMetricPoint> points) {
    for (var index = 1; index < points.length; index++) {
      if (points[index].day.difference(points[index - 1].day).inDays != 1) {
        return false;
      }
    }
    return true;
  }
}
