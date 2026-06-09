import 'first_session_pattern_category.dart';

enum FirstSessionConfidenceLabel {
  early,
  forming,
  strong,
}

/// Alternate first-pattern option when scores are close or the user corrects.
class FirstSessionPatternAlternative {
  const FirstSessionPatternAlternative({
    required this.title,
    required this.whyNoticed,
    required this.watchForText,
    required this.chips,
    required this.confidenceScore,
    this.categoryId = '',
  });

  final String title;
  final String whyNoticed;
  final String watchForText;
  final List<String> chips;
  final double confidenceScore;
  final String categoryId;

  Map<String, dynamic> toJson() => {
        'title': title,
        'whyNoticed': whyNoticed,
        'watchForText': watchForText,
        'chips': chips,
        'confidenceScore': confidenceScore,
        'categoryId': categoryId,
      };

  static FirstSessionPatternAlternative? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final title = json['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;
    final chipsRaw = json['chips'];
    final chips = chipsRaw is List
        ? chipsRaw.map((e) => e.toString().trim()).where((c) => c.isNotEmpty).toList()
        : <String>[];
    return FirstSessionPatternAlternative(
      title: title,
      whyNoticed: json['whyNoticed']?.toString().trim() ?? '',
      watchForText: json['watchForText']?.toString().trim() ?? '',
      chips: chips,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
      categoryId: json['categoryId']?.toString() ?? '',
    );
  }
}

/// Named pattern surfaced immediately after the user's first saved moment.
class FirstSessionPattern {
  FirstSessionPattern({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.whyNoticed,
    required this.watchForText,
    required this.chips,
    required this.confidenceLabel,
    required this.sourceTextPreview,
    required this.matchReason,
    required this.confidenceScore,
    this.matchedPhrases = const [],
    this.alternativePatterns = const [],
    this.userCanCorrect = true,
    this.categoryId = '',
    FirstSessionPatternCategory? category,
    this.competingCategoryScores = const {},
    this.ambiguityMargin = 1,
    this.negativeMatchPenaltyApplied = false,
    this.isAmbiguousMatch = false,
  }) : category =
            category ?? firstSessionPatternCategoryFromIdOrFallback(categoryId);

  final String id;
  final DateTime createdAt;
  final String title;
  final String whyNoticed;
  final String watchForText;
  final List<String> chips;
  final FirstSessionConfidenceLabel confidenceLabel;
  final String sourceTextPreview;
  final String matchReason;
  final double confidenceScore;
  final List<String> matchedPhrases;
  final List<FirstSessionPatternAlternative> alternativePatterns;
  final bool userCanCorrect;
  final String categoryId;
  final FirstSessionPatternCategory category;
  final Map<String, double> competingCategoryScores;
  final double ambiguityMargin;
  final bool negativeMatchPenaltyApplied;
  final bool isAmbiguousMatch;

  bool get isLowConfidence => confidenceScore < 0.45;

  bool get isLighterMoment => category == FirstSessionPatternCategory.lighter;

  String get noticedBecauseLine {
    if (matchedPhrases.isEmpty) return matchReason;
    final parts = matchedPhrases.take(3).toList();
    if (parts.length == 1) {
      return 'ArchiveMe noticed this because you mentioned ${parts.first}.';
    }
    if (parts.length == 2) {
      return 'ArchiveMe noticed this because you mentioned ${parts[0]} and ${parts[1]}.';
    }
    return 'ArchiveMe noticed this because you mentioned ${parts[0]}, ${parts[1]}, and ${parts[2]}.';
  }

  FirstSessionPattern copyWith({
    String? title,
    String? whyNoticed,
    String? watchForText,
    List<String>? chips,
    FirstSessionConfidenceLabel? confidenceLabel,
    String? matchReason,
    double? confidenceScore,
    List<String>? matchedPhrases,
    List<FirstSessionPatternAlternative>? alternativePatterns,
    bool? userCanCorrect,
    String? categoryId,
    FirstSessionPatternCategory? category,
    Map<String, double>? competingCategoryScores,
    double? ambiguityMargin,
    bool? negativeMatchPenaltyApplied,
    bool? isAmbiguousMatch,
  }) {
    final nextCategoryId = categoryId ?? this.categoryId;
    return FirstSessionPattern(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      whyNoticed: whyNoticed ?? this.whyNoticed,
      watchForText: watchForText ?? this.watchForText,
      chips: chips ?? this.chips,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
      sourceTextPreview: sourceTextPreview,
      matchReason: matchReason ?? this.matchReason,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      matchedPhrases: matchedPhrases ?? this.matchedPhrases,
      alternativePatterns: alternativePatterns ?? this.alternativePatterns,
      userCanCorrect: userCanCorrect ?? this.userCanCorrect,
      categoryId: nextCategoryId,
      category:
          category ?? firstSessionPatternCategoryFromIdOrFallback(nextCategoryId),
      competingCategoryScores:
          competingCategoryScores ?? this.competingCategoryScores,
      ambiguityMargin: ambiguityMargin ?? this.ambiguityMargin,
      negativeMatchPenaltyApplied:
          negativeMatchPenaltyApplied ?? this.negativeMatchPenaltyApplied,
      isAmbiguousMatch: isAmbiguousMatch ?? this.isAmbiguousMatch,
    );
  }

  FirstSessionPattern withAlternative(FirstSessionPatternAlternative alt) {
    return copyWith(
      title: alt.title,
      whyNoticed: alt.whyNoticed,
      watchForText: alt.watchForText,
      chips: alt.chips,
      confidenceScore: alt.confidenceScore,
      categoryId: alt.categoryId,
      confidenceLabel: FirstSessionConfidenceLabel.early,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'title': title,
        'whyNoticed': whyNoticed,
        'watchForText': watchForText,
        'chips': chips,
        'confidenceLabel': confidenceLabel.name,
        'sourceTextPreview': sourceTextPreview,
        'matchReason': matchReason,
        'confidenceScore': confidenceScore,
        'matchedPhrases': matchedPhrases,
        'alternativePatterns':
            alternativePatterns.map((a) => a.toJson()).toList(),
        'userCanCorrect': userCanCorrect,
        'categoryId': categoryId,
        'category': category.id,
        'competingCategoryScores': competingCategoryScores,
        'ambiguityMargin': ambiguityMargin,
        'negativeMatchPenaltyApplied': negativeMatchPenaltyApplied,
        'isAmbiguousMatch': isAmbiguousMatch,
      };

  static FirstSessionPattern? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final createdRaw = json['createdAt']?.toString();
    final createdAt = DateTime.tryParse(createdRaw ?? '');
    if (createdAt == null) return null;

    final chipsRaw = json['chips'];
    final chips = chipsRaw is List
        ? chipsRaw.map((e) => e.toString().trim()).where((c) => c.isNotEmpty).toList()
        : <String>[];

    final phrasesRaw = json['matchedPhrases'];
    final matchedPhrases = phrasesRaw is List
        ? phrasesRaw.map((e) => e.toString().trim()).where((p) => p.isNotEmpty).toList()
        : <String>[];

    final altRaw = json['alternativePatterns'];
    final alternatives = altRaw is List
        ? altRaw
            .whereType<Map>()
            .map((m) => FirstSessionPatternAlternative.fromJson(
                  Map<String, dynamic>.from(m),
                ))
            .whereType<FirstSessionPatternAlternative>()
            .toList()
        : <FirstSessionPatternAlternative>[];

    return FirstSessionPattern(
      id: id,
      createdAt: createdAt.toLocal(),
      title: title,
      whyNoticed: json['whyNoticed']?.toString().trim() ?? '',
      watchForText: json['watchForText']?.toString().trim() ?? '',
      chips: chips,
      confidenceLabel: _parseConfidence(json['confidenceLabel']?.toString() ?? ''),
      sourceTextPreview: json['sourceTextPreview']?.toString().trim() ?? '',
      matchReason: json['matchReason']?.toString().trim() ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
      matchedPhrases: matchedPhrases,
      alternativePatterns: alternatives,
      userCanCorrect: json['userCanCorrect'] as bool? ?? true,
      categoryId: json['categoryId']?.toString() ?? '',
      category: firstSessionPatternCategoryFromIdOrFallback(
        json['category']?.toString() ?? json['categoryId']?.toString(),
      ),
      competingCategoryScores: _parseScoreMap(json['competingCategoryScores']),
      ambiguityMargin: (json['ambiguityMargin'] as num?)?.toDouble() ?? 1,
      negativeMatchPenaltyApplied:
          json['negativeMatchPenaltyApplied'] as bool? ?? false,
      isAmbiguousMatch: json['isAmbiguousMatch'] as bool? ?? false,
    );
  }

  static Map<String, double> _parseScoreMap(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0),
    );
  }

  static FirstSessionConfidenceLabel _parseConfidence(String raw) {
    switch (raw) {
      case 'forming':
        return FirstSessionConfidenceLabel.forming;
      case 'strong':
        return FirstSessionConfidenceLabel.strong;
      default:
        return FirstSessionConfidenceLabel.early;
    }
  }
}
