/// Whether the proving-enough loop looks stronger, fading, mixed, or unclear.
enum AmbitionPressureDirection {
  stronger,
  fading,
  mixed,
  unclear;

  String get id => name;

  String get copy {
    switch (this) {
      case AmbitionPressureDirection.stronger:
        return 'The proving-enough loop may be getting stronger.';
      case AmbitionPressureDirection.fading:
        return 'The proving-enough loop may be fading.';
      case AmbitionPressureDirection.mixed:
        return 'The evidence is mixed.';
      case AmbitionPressureDirection.unclear:
        return 'ArchiveMe needs more moments before calling a direction.';
    }
  }
}

/// Monthly prove_enough review — stronger / fading / mixed / unclear.
class MonthlyAmbitionPressureReview {
  const MonthlyAmbitionPressureReview({
    required this.monthLabel,
    required this.totalProvingMoments,
    required this.pressureMomentCount,
    required this.choiceMomentCount,
    required this.restGuiltCount,
    required this.contradictionCount,
    required this.topTriggers,
    required this.direction,
    required this.directionEvidence,
    required this.whatChanged,
    required this.nextMonthMission,
    required this.whatRepeated,
    required this.whatSeemedToCostYou,
    required this.choiceVsPressureSummary,
    required this.restGuiltSummary,
    required this.triggerMapSummary,
  });

  static const screenTitle = 'Monthly ambition pressure review';

  static const whatRepeatedTitle = 'What repeated';
  static const whatCostTitle = 'What seemed to cost you';
  static const choiceVsPressureTitle = 'Choice vs pressure';
  static const restGuiltTitle = 'Rest guilt';
  static const triggerMapTitle = 'Trigger map';
  static const directionTitle = 'Is the loop getting stronger or fading?';
  static const nextMissionTitle = 'Next month\u2019s mission';

  static const proPreviewTitle = 'Monthly reviews are Pro';
  static const proPreviewBody =
      'Keep tracking whether the proving-enough loop fades, gets stronger, or changes.';
  static const proPreviewCta = 'See Pro';

  final String monthLabel;
  final int totalProvingMoments;
  final int pressureMomentCount;
  final int choiceMomentCount;
  final int restGuiltCount;
  final int contradictionCount;
  final List<String> topTriggers;
  final AmbitionPressureDirection direction;
  final List<String> directionEvidence;
  final String whatChanged;
  final String nextMonthMission;
  final String whatRepeated;
  final String whatSeemedToCostYou;
  final String choiceVsPressureSummary;
  final String restGuiltSummary;
  final String triggerMapSummary;

  bool get hasEnoughData => totalProvingMoments >= 2;
}