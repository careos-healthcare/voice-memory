/// Steps in the first-run pipeline. The paywall stays last.
enum OnboardingStep {
  valueWelcome,
  valueTrust,
  trialVoice,
  sampleGraph,
  paywall,
}

/// Decides which onboarding step comes next.
///
/// Value demonstration runs before the trial. [OnboardingStep.paywall] is
/// included only after the trial voice entry is complete, or when a save
/// would keep context past the trial window.
abstract final class OnboardingRouter {
  static const trialLimit = Duration(seconds: 30);

  static const steps = <OnboardingStep>[
    OnboardingStep.valueWelcome,
    OnboardingStep.valueTrust,
    OnboardingStep.trialVoice,
    OnboardingStep.sampleGraph,
    OnboardingStep.paywall,
  ];

  static bool trialWindowClosed(Duration elapsed) => elapsed >= trialLimit;

  static bool shouldShowPaywall({
    required bool hasCompletedTrial,
    required bool saveBeyondTrialBounds,
  }) {
    return hasCompletedTrial || saveBeyondTrialBounds;
  }

  static List<OnboardingStep> visibleSteps({
    required bool hasCompletedTrial,
    required bool saveBeyondTrialBounds,
  }) {
    final showPaywall = shouldShowPaywall(
      hasCompletedTrial: hasCompletedTrial,
      saveBeyondTrialBounds: saveBeyondTrialBounds,
    );
    return [
      for (final step in steps)
        if (step != OnboardingStep.paywall || showPaywall) step,
    ];
  }

  /// Next step, or null when the pipeline is finished.
  ///
  /// A save past the trial window jumps straight to the paywall.
  static OnboardingStep? next({
    required OnboardingStep current,
    required bool hasCompletedTrial,
    bool saveBeyondTrialBounds = false,
  }) {
    if (saveBeyondTrialBounds) return OnboardingStep.paywall;
    final visible = visibleSteps(
      hasCompletedTrial: hasCompletedTrial,
      saveBeyondTrialBounds: false,
    );
    final index = visible.indexOf(current);
    if (index < 0 || index + 1 >= visible.length) return null;
    return visible[index + 1];
  }
}
