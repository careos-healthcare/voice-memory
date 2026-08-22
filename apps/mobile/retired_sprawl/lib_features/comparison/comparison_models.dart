import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// Preset temporal comparison ranges — baseline period vs current period.
enum ComparisonTemporalRange {
  thirtyDaysVsToday(
    label: '30 days ago vs today',
    shortLabel: '30 days',
    thenDescription: '30–60 days ago',
    nowDescription: 'Last 30 days',
    baselineDaysBack: 60,
    currentDaysBack: 30,
  ),
  sixMonthsVsToday(
    label: '6 months ago vs today',
    shortLabel: '6 months',
    thenDescription: '6–12 months ago',
    nowDescription: 'Last 6 months',
    baselineDaysBack: 365,
    currentDaysBack: 180,
  ),
  oneYearVsToday(
    label: '1 year ago vs today',
    shortLabel: '1 year',
    thenDescription: '12–24 months ago',
    nowDescription: 'Last 12 months',
    baselineDaysBack: 730,
    currentDaysBack: 365,
  ),
  multiYearShift(
    label: 'Multi-year shift',
    shortLabel: 'Multi-year',
    thenDescription: 'Earlier archive',
    nowDescription: 'Recent archive',
    baselineDaysBack: null,
    currentDaysBack: null,
  );

  const ComparisonTemporalRange({
    required this.label,
    required this.shortLabel,
    required this.thenDescription,
    required this.nowDescription,
    required this.baselineDaysBack,
    required this.currentDaysBack,
  });

  final String label;
  final String shortLabel;
  final String thenDescription;
  final String nowDescription;
  final int? baselineDaysBack;
  final int? currentDaysBack;
}

enum ComparisonShiftKind {
  strengthened,
  weakened,
  emerged,
  dropped,
  recurringContradiction,
}

/// Verbatim cite from journal or fact ledger.
class ComparisonCitation {
  const ComparisonCitation({
    required this.entryId,
    required this.quote,
    required this.recordedAt,
    this.factLabel,
  });

  final String entryId;
  final String quote;
  final DateTime recordedAt;
  final String? factLabel;
}

/// One side of the temporal split.
class ComparisonPeriodSnapshot {
  const ComparisonPeriodSnapshot({
    required this.label,
    required this.beliefText,
    required this.confidencePercent,
    required this.confidenceBand,
    required this.citations,
    required this.factCount,
    required this.entryCount,
    required this.periodStart,
    required this.periodEnd,
  });

  final String label;
  final String beliefText;
  final int confidencePercent;
  final PatternMatchConfidenceBand confidenceBand;
  final List<ComparisonCitation> citations;
  final int factCount;
  final int entryCount;
  final DateTime periodStart;
  final DateTime periodEnd;

  bool get hasBelief => beliefText.trim().isNotEmpty;
}

/// Detected shift between baseline and current belief states.
class ComparisonBeliefShift {
  const ComparisonBeliefShift({
    required this.kind,
    required this.headline,
    required this.thenBelief,
    required this.nowBelief,
    required this.deltaBand,
    required this.deltaBadgeLabel,
    required this.thenCitations,
    required this.nowCitations,
    this.contradictionNote,
  });

  final ComparisonShiftKind kind;
  final String headline;
  final String thenBelief;
  final String nowBelief;
  final PatternMatchConfidenceBand deltaBand;
  final String deltaBadgeLabel;
  final List<ComparisonCitation> thenCitations;
  final List<ComparisonCitation> nowCitations;
  final String? contradictionNote;
}

/// Full explorer payload for the Then vs Now screen.
class ComparisonExplorerResult {
  const ComparisonExplorerResult({
    required this.range,
    required this.then,
    required this.now,
    required this.shifts,
    required this.droppedAssumptions,
    required this.hasEnoughEvidence,
  });

  final ComparisonTemporalRange range;
  final ComparisonPeriodSnapshot then;
  final ComparisonPeriodSnapshot now;
  final List<ComparisonBeliefShift> shifts;
  final List<String> droppedAssumptions;
  final bool hasEnoughEvidence;
}