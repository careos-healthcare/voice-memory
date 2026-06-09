import '../archive_evolution/archive_evolution_models.dart';
import '../archive_explanations/explanation_models.dart';

/// Priority order for the single hero insight.
enum MostImportantInsightPriority {
  archiveWasWrong,
  confidenceChanged,
  dailyDiscovery,
  challenge,
  beliefChange,
  returnReason,
}

class MostImportantInsight {
  const MostImportantInsight({
    required this.headline,
    required this.summary,
    required this.why,
    required this.confidence,
    required this.evidenceIds,
    required this.openedRoute,
    required this.priority,
    required this.createdAt,
    required this.insightRef,
    this.askPrompt,
    this.isArchiveWasWrong = false,
  });

  final String headline;
  final String summary;
  final String why;
  final double confidence;
  final List<String> evidenceIds;
  final String openedRoute;
  final MostImportantInsightPriority priority;
  final DateTime createdAt;
  final ArchiveInsightRef insightRef;
  final String? askPrompt;
  final bool isArchiveWasWrong;
}

class ArchiveWasWrongInsight {
  const ArchiveWasWrongInsight({
    required this.id,
    required this.headline,
    required this.summary,
    required this.evidenceIds,
    required this.confidence,
    required this.insightRef,
    required this.shiftLabel,
  });

  final String id;
  final String headline;
  final String summary;
  final List<String> evidenceIds;
  final int confidence;
  final ArchiveInsightRef insightRef;
  final String shiftLabel;
}

enum BeliefConfidenceTrend {
  rising,
  falling,
  stable,
}

class BeliefUnderReview {
  const BeliefUnderReview({
    required this.belief,
    required this.confidencePercent,
    required this.trend,
    required this.trendLabel,
    required this.evidenceIds,
  });

  final String belief;
  final int confidencePercent;
  final BeliefConfidenceTrend trend;
  final String trendLabel;
  final List<String> evidenceIds;
}

class WhatChangedTodayLine {
  const WhatChangedTodayLine({
    required this.label,
    required this.before,
    required this.after,
    this.displayText,
  });

  final String label;
  final String before;
  final String after;

  /// Warm reflective line for UI; when null, [WarmArchiveCopy.formatWhatChangedLine] derives one.
  final String? displayText;
}

class WhatChangedToday {
  const WhatChangedToday({
    required this.lines,
    required this.insightRef,
    required this.evidenceIds,
  });

  final List<WhatChangedTodayLine> lines;
  final ArchiveInsightRef insightRef;
  final List<String> evidenceIds;

  bool get hasContent => lines.isNotEmpty;
}

class DiscoveryStreak {
  const DiscoveryStreak({
    required this.consecutiveDays,
    required this.hadDiscoveryToday,
  });

  final int consecutiveDays;
  final bool hadDiscoveryToday;
}

class LivingArchiveView {
  const LivingArchiveView({
    required this.mostImportant,
    this.archiveWasWrong,
    this.beliefUnderReview,
    this.whatChangedToday,
    required this.discoveryStreak,
    this.hasMoreDiscoveries = false,
    this.evolution,
    this.lastArchiveUpdateAt,
  });

  final MostImportantInsight? mostImportant;
  final ArchiveWasWrongInsight? archiveWasWrong;
  final BeliefUnderReview? beliefUnderReview;
  final WhatChangedToday? whatChangedToday;
  final DiscoveryStreak discoveryStreak;
  final bool hasMoreDiscoveries;
  final ArchiveEvolution? evolution;
  final DateTime? lastArchiveUpdateAt;

  bool get hasQuickViewContent =>
      evolution != null ||
      (whatChangedToday?.hasContent ?? false) ||
      discoveryStreak.consecutiveDays > 0;

  /// Secondary items hidden behind View More on Archive open.
  bool get hasCollapsedContent =>
      (whatChangedToday?.hasContent ?? false) ||
      mostImportant != null;
}
