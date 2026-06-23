/// Deterministic next-evidence plan readout — computed locally, never persisted.
class NextEvidencePlanResult {
  const NextEvidencePlanResult({
    required this.title,
    required this.body,
    required this.primaryActionLabel,
    required this.primaryActionRoute,
    required this.showProLine,
    this.watchlistLine,
    this.returnRitualLine,
    this.secondaryLine,
    this.showReviewWatchlistAction = false,
  });

  final String title;
  final String body;
  final String? watchlistLine;
  final String? returnRitualLine;
  final String? secondaryLine;
  final String primaryActionLabel;
  final String primaryActionRoute;
  final bool showReviewWatchlistAction;
  final bool showProLine;
}

/// Starter prompt at zero entries.
class NextEvidencePlanTeaser {
  const NextEvidencePlanTeaser({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}
