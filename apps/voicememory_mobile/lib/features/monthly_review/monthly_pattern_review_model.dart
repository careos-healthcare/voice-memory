/// A simple monthly recap of what kept repeating, what got lighter or heavier,
/// what helped, and one check to carry into next month.
///
/// Every section is optional — empty stays empty so the recap never overclaims.
class MonthlyPatternReview {
  const MonthlyPatternReview({
    required this.monthLabel,
    required this.momentCount,
    required this.checkInCount,
    this.keptRepeating,
    this.gotLighter,
    this.gotHeavier,
    this.helped,
    this.nextCheck,
    required this.confidenceLabel,
  });

  /// Human month name, e.g. "June".
  final String monthLabel;

  /// Saved moments counted toward this recap (this month).
  final int momentCount;

  /// Completed check-ins counted toward this recap (this month).
  final int checkInCount;

  final String? keptRepeating;
  final String? gotLighter;
  final String? gotHeavier;
  final String? helped;

  /// One useful check to carry into next month.
  final String? nextCheck;

  final String confidenceLabel;

  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;

  /// True when at least one recap section has content to show.
  bool get hasContent =>
      _has(keptRepeating) ||
      _has(gotLighter) ||
      _has(gotHeavier) ||
      _has(helped) ||
      hasNextCheck;

  static bool _has(String? v) => (v ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'monthLabel': monthLabel,
        'momentCount': momentCount,
        'checkInCount': checkInCount,
        if (keptRepeating != null) 'keptRepeating': keptRepeating,
        if (gotLighter != null) 'gotLighter': gotLighter,
        if (gotHeavier != null) 'gotHeavier': gotHeavier,
        if (helped != null) 'helped': helped,
        if (nextCheck != null) 'nextCheck': nextCheck,
        'confidenceLabel': confidenceLabel,
      };

  static MonthlyPatternReview? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final monthLabel = map['monthLabel'] as String?;
    if (monthLabel == null || monthLabel.isEmpty) return null;
    return MonthlyPatternReview(
      monthLabel: monthLabel,
      momentCount: _int(map['momentCount']),
      checkInCount: _int(map['checkInCount']),
      keptRepeating: map['keptRepeating'] as String?,
      gotLighter: map['gotLighter'] as String?,
      gotHeavier: map['gotHeavier'] as String?,
      helped: map['helped'] as String?,
      nextCheck: map['nextCheck'] as String?,
      confidenceLabel: (map['confidenceLabel'] as String?) ?? '',
    );
  }

  static int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);
}
