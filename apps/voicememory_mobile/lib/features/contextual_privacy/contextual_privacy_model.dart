/// Surfaces where contextual privacy reassurance may appear.
enum ContextualPrivacySurface {
  firstProofPayoff('first_proof_payoff'),
  beliefChangeMoment('belief_change_moment'),
  patternDetail('pattern_detail'),
  weeklyReview('weekly_review'),
  privateReport('private_report');

  const ContextualPrivacySurface(this.analyticsSource);

  final String analyticsSource;
}
