/// Selected review day — metadata only.
enum ReviewRitualDay { sunday }

/// Selected daypart for the review ritual.
enum ReviewRitualDaypart { morning, afternoon, evening }

/// Local review ritual preferences — no journal text.
class ReviewRitual {
  const ReviewRitual({
    required this.selectedDay,
    required this.selectedDaypart,
    required this.focusRepeated,
    required this.focusChanged,
    required this.focusWatchNext,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReviewRitual.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return ReviewRitual.empty;
    }
    final createdRaw = json['createdAt'] as String?;
    final updatedRaw = json['updatedAt'] as String?;
    return ReviewRitual(
      selectedDay: ReviewRitualDay.values.firstWhere(
        (day) => day.name == json['selectedDay'],
        orElse: () => ReviewRitualDay.sunday,
      ),
      selectedDaypart: ReviewRitualDaypart.values.firstWhere(
        (part) => part.name == json['selectedDaypart'],
        orElse: () => ReviewRitualDaypart.evening,
      ),
      focusRepeated: json['focusRepeated'] == true,
      focusChanged: json['focusChanged'] == true,
      focusWatchNext: json['focusWatchNext'] == true,
      createdAt: createdRaw != null
          ? DateTime.parse(createdRaw).toLocal()
          : DateTime.now(),
      updatedAt: updatedRaw != null
          ? DateTime.parse(updatedRaw).toLocal()
          : DateTime.now(),
    );
  }

  final ReviewRitualDay selectedDay;
  final ReviewRitualDaypart selectedDaypart;
  final bool focusRepeated;
  final bool focusChanged;
  final bool focusWatchNext;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isConfigured => focusRepeated || focusChanged || focusWatchNext;

  Map<String, dynamic> toJson() => {
    'selectedDay': selectedDay.name,
    'selectedDaypart': selectedDaypart.name,
    'focusRepeated': focusRepeated,
    'focusChanged': focusChanged,
    'focusWatchNext': focusWatchNext,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  ReviewRitual copyWith({
    ReviewRitualDay? selectedDay,
    ReviewRitualDaypart? selectedDaypart,
    bool? focusRepeated,
    bool? focusChanged,
    bool? focusWatchNext,
    DateTime? updatedAt,
  }) => ReviewRitual(
    selectedDay: selectedDay ?? this.selectedDay,
    selectedDaypart: selectedDaypart ?? this.selectedDaypart,
    focusRepeated: focusRepeated ?? this.focusRepeated,
    focusChanged: focusChanged ?? this.focusChanged,
    focusWatchNext: focusWatchNext ?? this.focusWatchNext,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static final empty = ReviewRitual(
    selectedDay: ReviewRitualDay.sunday,
    selectedDaypart: ReviewRitualDaypart.evening,
    focusRepeated: false,
    focusChanged: false,
    focusWatchNext: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Engine input — counts and ritual metadata only.
class ReviewRitualInput {
  const ReviewRitualInput({
    required this.realSavedMomentCount,
    required this.weeklyReviewAvailable,
    this.ritual,
    this.sampleMode = false,
  });

  final int realSavedMomentCount;
  final bool weeklyReviewAvailable;
  final ReviewRitual? ritual;
  final bool sampleMode;
}

/// Engine output for cards and screen.
class ReviewRitualResult {
  const ReviewRitualResult({
    required this.hasRitual,
    required this.showOnArchiveHome,
    required this.hasCard,
    required this.summaryLabel,
    required this.helperText,
    required this.privacyLine,
    required this.cardHeadline,
    required this.cardSummary,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.secondaryCtaLabel,
    required this.secondaryRoute,
    required this.weeklyReviewAvailable,
    required this.insufficientEntries,
  });

  final bool hasRitual;
  final bool showOnArchiveHome;
  final bool hasCard;
  final String summaryLabel;
  final String helperText;
  final String privacyLine;
  final String cardHeadline;
  final String cardSummary;
  final String primaryCtaLabel;
  final String primaryRoute;
  final String secondaryCtaLabel;
  final String secondaryRoute;
  final bool weeklyReviewAvailable;
  final bool insufficientEntries;

  static const empty = ReviewRitualResult(
    hasRitual: false,
    showOnArchiveHome: false,
    hasCard: false,
    summaryLabel: '',
    helperText: '',
    privacyLine: '',
    cardHeadline: '',
    cardSummary: '',
    primaryCtaLabel: '',
    primaryRoute: '',
    secondaryCtaLabel: '',
    secondaryRoute: '',
    weeklyReviewAvailable: false,
    insufficientEntries: true,
  );
}