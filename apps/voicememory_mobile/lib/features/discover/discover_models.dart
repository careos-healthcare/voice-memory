import '../../models/journal_entry.dart';

/// Insight depth unlocked from reflection count.
enum DiscoverInsightMode {
  empty,
  early,
  growing,
  full;

  static DiscoverInsightMode forCount(int eligibleCount) {
    if (eligibleCount <= 0) return DiscoverInsightMode.empty;
    if (eligibleCount <= 4) return DiscoverInsightMode.early;
    if (eligibleCount <= 20) return DiscoverInsightMode.growing;
    return DiscoverInsightMode.full;
  }

  String get emptyStateMessage => switch (this) {
        DiscoverInsightMode.empty => '',
        DiscoverInsightMode.early =>
          'Keep recording. Your archive needs more spoken detail before beliefs can surface.',
        DiscoverInsightMode.growing => '',
        DiscoverInsightMode.full => '',
      };
}

class DiscoverHeaderStats {
  const DiscoverHeaderStats({
    required this.totalRecordings,
    required this.totalReflections,
    required this.daysTracked,
    this.firstRecordingDate,
  });

  final int totalRecordings;
  final int totalReflections;
  final int daysTracked;
  final DateTime? firstRecordingDate;
}

class DiscoverBeliefCard {
  const DiscoverBeliefCard({
    required this.statement,
    required this.confidencePercent,
    required this.evidenceCount,
    this.firstObserved,
    this.lastReinforced,
    required this.supportingEntries,
  });

  final String statement;
  final int confidencePercent;
  final int evidenceCount;
  final DateTime? firstObserved;
  final DateTime? lastReinforced;
  final List<JournalEntry> supportingEntries;
}

class DiscoverBeliefChange {
  const DiscoverBeliefChange({
    required this.type,
    required this.headline,
    required this.beliefStatement,
    required this.priorLabel,
    required this.priorPercent,
    required this.currentLabel,
    required this.currentPercent,
    required this.magnitude,
    required this.evidenceEntryIds,
    required this.confidence,
    this.dateRangeLabel = '',
    this.before,
    this.after,
  });

  final String type;
  final String headline;
  final String beliefStatement;
  final String priorLabel;
  final int priorPercent;
  final String currentLabel;
  final int currentPercent;
  final int magnitude;
  final List<String> evidenceEntryIds;
  final int confidence;
  final String dateRangeLabel;
  final String? before;
  final String? after;
}

enum ThemeTrendDirection { up, down, flat }

class DiscoverThemeInsight {
  const DiscoverThemeInsight({
    required this.name,
    required this.themeKey,
    required this.frequency,
    required this.trend,
    this.evidenceEntryIds = const [],
  });

  final String name;
  final String themeKey;
  final int frequency;
  final ThemeTrendDirection trend;
  final List<String> evidenceEntryIds;
}

class DiscoverContradictionInsight {
  const DiscoverContradictionInsight({
    required this.statementA,
    required this.statementB,
    required this.dateA,
    required this.dateB,
    required this.confidenceScore,
    required this.entryIdA,
    required this.entryIdB,
  });

  final String statementA;
  final String statementB;
  final DateTime dateA;
  final DateTime dateB;
  final int confidenceScore;
  final String entryIdA;
  final String entryIdB;
}

class DiscoverBlindSpotCard {
  const DiscoverBlindSpotCard({
    required this.id,
    required this.headline,
    required this.observation,
    required this.confidence,
    required this.evidenceCount,
    required this.entryIds,
  });

  final String id;
  final String headline;
  final String observation;
  final int confidence;
  final int evidenceCount;
  final List<String> entryIds;
}

class DiscoverChapterSummary {
  const DiscoverChapterSummary({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.summary,
    required this.entryCount,
    required this.entryIds,
  });

  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String summary;
  final int entryCount;
  final List<String> entryIds;
}

class DiscoverMomentumStats {
  const DiscoverMomentumStats({
    required this.recordingsThisWeek,
    required this.reflectionsThisWeek,
    required this.longestStreak,
    required this.currentStreak,
  });

  final int recordingsThisWeek;
  final int reflectionsThisWeek;
  final int longestStreak;
  final int currentStreak;
}

class DiscoverGrowthMonth {
  const DiscoverGrowthMonth({
    required this.month,
    required this.year,
    required this.label,
    required this.summary,
  });

  final int month;
  final int year;
  final String label;
  final String summary;
}

class DiscoverArchiveAnswer {
  const DiscoverArchiveAnswer({
    required this.prompt,
    required this.answerLines,
    required this.citedEntryIds,
  });

  final String prompt;
  final List<String> answerLines;
  final List<String> citedEntryIds;
}

/// Full dashboard snapshot for Discover Yourself.
class DiscoverYourselfSnapshot {
  const DiscoverYourselfSnapshot({
    required this.mode,
    required this.generatedAt,
    required this.header,
    this.belief,
    this.beliefChanges = const [],
    this.themes = const [],
    this.contradictions = const [],
    this.blindSpots = const [],
    this.chapters = const [],
    this.momentum,
    this.growthTimeline = const [],
    required this.askPrompts,
  });

  final DiscoverInsightMode mode;
  final DateTime generatedAt;
  final DiscoverHeaderStats header;
  final DiscoverBeliefCard? belief;
  final List<DiscoverBeliefChange> beliefChanges;
  final List<DiscoverThemeInsight> themes;
  final List<DiscoverContradictionInsight> contradictions;
  final List<DiscoverBlindSpotCard> blindSpots;
  final List<DiscoverChapterSummary> chapters;
  final DiscoverMomentumStats? momentum;
  final List<DiscoverGrowthMonth> growthTimeline;
  final List<String> askPrompts;

  bool get showFullSections => mode == DiscoverInsightMode.full;

  bool get showEarlyInsights =>
      mode == DiscoverInsightMode.growing || mode == DiscoverInsightMode.full;
}
