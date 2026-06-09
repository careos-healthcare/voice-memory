/// The single best fix to try next for the tomorrow check-in hook.
enum HookRescueAction {
  none,
  reminder,
  guidedCheckIn,
  sharperQuestion,
  betterResult,
  betterFirstRecord,
}

extension HookRescueActionIds on HookRescueAction {
  String get id => name;
}

/// Confidence in the recommended fix, based on how much trial data exists.
enum HookRescueConfidence {
  low,
  medium,
  high,
}

extension HookRescueConfidenceIds on HookRescueConfidence {
  String get id => name;
}

/// How hard to push a given fix, based on how strong the diagnosis signal is.
enum HookRescueIntensity {
  normal,
  elevated,
  aggressive,
}

extension HookRescueIntensityIds on HookRescueIntensity {
  String get id => name;
}

/// Which rescue fix(es) to surface, gated by diagnosis.
class HookRescueDecision {
  const HookRescueDecision({
    required this.primaryAction,
    required this.secondaryActions,
    required this.reason,
    required this.confidence,
    this.intensities = const {},
  });

  final HookRescueAction primaryAction;
  final List<HookRescueAction> secondaryActions;
  final String reason;
  final HookRescueConfidence confidence;

  /// Escalation level per action. Missing entries are [HookRescueIntensity.normal].
  final Map<HookRescueAction, HookRescueIntensity> intensities;

  /// True when [action] is the primary fix or a secondary fix.
  bool includes(HookRescueAction action) =>
      primaryAction == action || secondaryActions.contains(action);

  /// How hard to push [action]; normal when the action is not triggered.
  HookRescueIntensity intensityFor(HookRescueAction action) =>
      intensities[action] ?? HookRescueIntensity.normal;

  static const HookRescueDecision none = HookRescueDecision(
    primaryAction: HookRescueAction.none,
    secondaryActions: [],
    reason: 'No clear fix needed yet.',
    confidence: HookRescueConfidence.low,
  );
}
