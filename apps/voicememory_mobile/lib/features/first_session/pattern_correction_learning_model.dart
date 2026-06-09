/// Where a pattern correction was recorded.
enum PatternCorrectionLearningSource {
  firstSession,
  activeThread,
  watchFor,
}

extension PatternCorrectionLearningSourceIds on PatternCorrectionLearningSource {
  String get id => name;
}

PatternCorrectionLearningSource? patternCorrectionLearningSourceFromId(
  String? raw,
) {
  if (raw == null || raw.isEmpty) return null;
  for (final s in PatternCorrectionLearningSource.values) {
    if (s.id == raw) return s;
  }
  return null;
}

/// One learned correction used to improve the next pattern suggestion.
class PatternCorrectionLearning {
  const PatternCorrectionLearning({
    required this.id,
    required this.createdAt,
    required this.originalTitle,
    required this.correctedTitle,
    required this.originalCategoryId,
    required this.correctedCategoryId,
    required this.reflectionSnippet,
    required this.matchedPhrases,
    required this.correctedWatchForText,
    required this.source,
    this.usedForNextPrompt = false,
  });

  final String id;
  final DateTime createdAt;
  final String originalTitle;
  final String correctedTitle;
  final String originalCategoryId;
  final String correctedCategoryId;
  final String reflectionSnippet;
  final List<String> matchedPhrases;
  final String correctedWatchForText;
  final PatternCorrectionLearningSource source;
  final bool usedForNextPrompt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'originalTitle': originalTitle,
        'correctedTitle': correctedTitle,
        'originalCategoryId': originalCategoryId,
        'correctedCategoryId': correctedCategoryId,
        'reflectionSnippet': reflectionSnippet,
        'matchedPhrases': matchedPhrases,
        'correctedWatchForText': correctedWatchForText,
        'source': source.id,
        'usedForNextPrompt': usedForNextPrompt,
      };

  static PatternCorrectionLearning? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final createdRaw = json['createdAt']?.toString();
    final createdAt = createdRaw != null
        ? DateTime.tryParse(createdRaw)
        : null;
    if (createdAt == null) return null;
    final source = patternCorrectionLearningSourceFromId(
          json['source']?.toString(),
        ) ??
        PatternCorrectionLearningSource.firstSession;
    final phrasesRaw = json['matchedPhrases'];
    final matchedPhrases = phrasesRaw is List
        ? phrasesRaw
            .map((e) => e.toString().trim())
            .where((p) => p.isNotEmpty)
            .toList()
        : <String>[];
    return PatternCorrectionLearning(
      id: id,
      createdAt: createdAt,
      originalTitle: json['originalTitle']?.toString().trim() ?? '',
      correctedTitle: json['correctedTitle']?.toString().trim() ?? '',
      originalCategoryId: json['originalCategoryId']?.toString() ?? '',
      correctedCategoryId: json['correctedCategoryId']?.toString() ?? '',
      reflectionSnippet: json['reflectionSnippet']?.toString().trim() ?? '',
      matchedPhrases: matchedPhrases,
      correctedWatchForText:
          json['correctedWatchForText']?.toString().trim() ?? '',
      source: source,
      usedForNextPrompt: json['usedForNextPrompt'] == true,
    );
  }

  PatternCorrectionLearning copyWith({bool? usedForNextPrompt}) {
    return PatternCorrectionLearning(
      id: id,
      createdAt: createdAt,
      originalTitle: originalTitle,
      correctedTitle: correctedTitle,
      originalCategoryId: originalCategoryId,
      correctedCategoryId: correctedCategoryId,
      reflectionSnippet: reflectionSnippet,
      matchedPhrases: matchedPhrases,
      correctedWatchForText: correctedWatchForText,
      source: source,
      usedForNextPrompt: usedForNextPrompt ?? this.usedForNextPrompt,
    );
  }
}

/// Aggregate stats for developer QA screens.
class PatternCorrectionLearningSummary {
  const PatternCorrectionLearningSummary({
    required this.totalLearned,
    required this.usedForNextPromptCount,
    required this.mostCorrectedCategoryId,
    required this.mostCorrectedTitle,
    required this.recent,
  });

  final int totalLearned;
  final int usedForNextPromptCount;
  final String mostCorrectedCategoryId;
  final String mostCorrectedTitle;
  final List<PatternCorrectionLearning> recent;
}
