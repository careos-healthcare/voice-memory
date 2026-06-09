/// A single, plain-language map of one recurring pattern: how often it shows
/// up, when it tends to start, how it usually feels, what makes it lighter or
/// heavier, and the one useful thing to check next.
class PatternMap {
  const PatternMap({
    required this.patternTitle,
    required this.seenCount,
    this.lastSeenDate,
    this.usuallyStartsBefore,
    this.oftenFeelsLike,
    this.getsLighterWhen,
    this.getsHeavierWhen,
    this.nextCheck,
    required this.confidenceLabel,
  });

  final String patternTitle;
  final int seenCount;
  final DateTime? lastSeenDate;
  final String? usuallyStartsBefore;
  final String? oftenFeelsLike;
  final String? getsLighterWhen;
  final String? getsHeavierWhen;
  final String? nextCheck;
  final String confidenceLabel;

  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;

  PatternMap copyWith({
    String? patternTitle,
    int? seenCount,
    DateTime? lastSeenDate,
    String? usuallyStartsBefore,
    String? oftenFeelsLike,
    String? getsLighterWhen,
    String? getsHeavierWhen,
    String? nextCheck,
    String? confidenceLabel,
  }) {
    return PatternMap(
      patternTitle: patternTitle ?? this.patternTitle,
      seenCount: seenCount ?? this.seenCount,
      lastSeenDate: lastSeenDate ?? this.lastSeenDate,
      usuallyStartsBefore: usuallyStartsBefore ?? this.usuallyStartsBefore,
      oftenFeelsLike: oftenFeelsLike ?? this.oftenFeelsLike,
      getsLighterWhen: getsLighterWhen ?? this.getsLighterWhen,
      getsHeavierWhen: getsHeavierWhen ?? this.getsHeavierWhen,
      nextCheck: nextCheck ?? this.nextCheck,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
    );
  }
}
