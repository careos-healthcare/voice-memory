/// Time ranges for the comparison explorer temporal view.
enum ComparisonTemporalWindow {
  /// Last 14 days — primary interval for New Parent / Grief-Loss lenses.
  fortnight(days: 14, requiresPro: false),

  /// Last 30 days — included on the free tier.
  recent(days: 30, requiresPro: false),

  /// Last 90 days — Pro unlocks the full citation thread.
  quarter(days: 90, requiresPro: true),

  /// Last 180 days — Pro unlocks the full citation thread.
  halfYear(days: 180, requiresPro: true),

  /// Entire on-device archive — Pro unlocks the full citation thread.
  allTime(days: null, requiresPro: true);

  const ComparisonTemporalWindow({required this.days, required this.requiresPro});

  final int? days;
  final bool requiresPro;

  String get label => switch (this) {
    ComparisonTemporalWindow.fortnight => 'Last 2 weeks',
    ComparisonTemporalWindow.recent => 'Last 30 days',
    ComparisonTemporalWindow.quarter => 'Last 3 months',
    ComparisonTemporalWindow.halfYear => 'Last 6 months',
    ComparisonTemporalWindow.allTime => 'All time',
  };

  String get headline => switch (this) {
    ComparisonTemporalWindow.fortnight => 'How have I changed over the last 2 weeks?',
    ComparisonTemporalWindow.recent => 'How have I changed recently?',
    ComparisonTemporalWindow.quarter => 'How have I changed over the last 3 months?',
    ComparisonTemporalWindow.halfYear => 'How have I changed over the last 6 months?',
    ComparisonTemporalWindow.allTime => 'How has my archive evolved?',
  };

  DateTime? windowStart({required DateTime now}) {
    final dayCount = days;
    if (dayCount == null) return null;
    return now.subtract(Duration(days: dayCount));
  }

  /// Parses route/query wire values such as `fortnight` or `recent`.
  static ComparisonTemporalWindow? fromWire(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final window in values) {
      if (window.name == raw.trim()) return window;
    }
    return null;
  }
}