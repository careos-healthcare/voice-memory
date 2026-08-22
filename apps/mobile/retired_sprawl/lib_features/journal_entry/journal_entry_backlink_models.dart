import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

extension PatternMatchConfidenceBandJournalSort on PatternMatchConfidenceBand {
  int get journalSortRank => switch (this) {
    PatternMatchConfidenceBand.strong => 0,
    PatternMatchConfidenceBand.solid => 1,
    PatternMatchConfidenceBand.emerging => 2,
    PatternMatchConfidenceBand.weak => 3,
  };
}

enum JournalEntryDerivedInsightKind {
  belief,
  contradiction,
  blindSpot,
  surprise,
}

/// An archive insight that currently cites this journal entry as evidence.
class JournalEntryDerivedInsight {
  const JournalEntryDerivedInsight({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.confidenceBand,
    this.supportingFactIds = const [],
  });

  final String id;
  final JournalEntryDerivedInsightKind kind;
  final String title;
  final String subtitle;
  final PatternMatchConfidenceBand confidenceBand;
  final List<String> supportingFactIds;

  String get kindLabel => switch (kind) {
    JournalEntryDerivedInsightKind.belief => 'Belief',
    JournalEntryDerivedInsightKind.contradiction => 'Contradiction',
    JournalEntryDerivedInsightKind.blindSpot => 'Blind spot',
    JournalEntryDerivedInsightKind.surprise => 'Surprise',
  };
}

/// A transcript sentence linked to citable facts and derived insights.
class JournalEntryQuoteHighlight {
  const JournalEntryQuoteHighlight({
    required this.start,
    required this.end,
    required this.sentence,
    required this.linkedInsights,
    required this.factValues,
  });

  final int start;
  final int end;
  final String sentence;
  final List<JournalEntryDerivedInsight> linkedInsights;
  final List<String> factValues;
}

class JournalEntryBacklinkSnapshot {
  const JournalEntryBacklinkSnapshot({
    required this.derivedInsights,
    required this.quoteHighlights,
  });

  const JournalEntryBacklinkSnapshot.empty()
      : derivedInsights = const [],
        quoteHighlights = const [];

  final List<JournalEntryDerivedInsight> derivedInsights;
  final List<JournalEntryQuoteHighlight> quoteHighlights;

  bool get isEmpty =>
      derivedInsights.isEmpty && quoteHighlights.isEmpty;
}