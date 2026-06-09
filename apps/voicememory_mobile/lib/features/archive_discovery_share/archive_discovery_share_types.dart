/// Share card kinds for Archive Discovery Share Cards V2.
enum ArchiveDiscoveryShareCardType {
  beliefChange,
  beliefLifecycle,
  patternDiscovery,
  milestone,
  contradiction,
  changeDetected,
  monthlyReviewInsight,
  surpriseObservation;

  String get analyticsValue => switch (this) {
        beliefChange => 'belief_change',
        beliefLifecycle => 'belief_lifecycle',
        patternDiscovery => 'pattern_discovery',
        milestone => 'milestone',
        contradiction => 'contradiction',
        changeDetected => 'change_detected',
        monthlyReviewInsight => 'monthly_review_insight',
        surpriseObservation => 'surprise_observation',
      };

  String get displayLabel => switch (this) {
        beliefChange => 'Theory change',
        beliefLifecycle => 'Belief lifecycle',
        patternDiscovery => 'Pattern discovery',
        milestone => 'Milestone',
        contradiction => 'Contradiction',
        changeDetected => 'Change detected',
        monthlyReviewInsight => 'Monthly review',
        surpriseObservation => 'Surprise',
      };
}
