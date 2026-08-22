import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// Sort key for evidence ledger inspect rows — strongest confidence first.
extension PatternMatchConfidenceBandSort on PatternMatchConfidenceBand {
  int get ledgerSortRank => switch (this) {
    PatternMatchConfidenceBand.strong => 0,
    PatternMatchConfidenceBand.solid => 1,
    PatternMatchConfidenceBand.emerging => 2,
    PatternMatchConfidenceBand.weak => 3,
  };
}

enum EvidenceLedgerItemKind { belief, contradiction, blindSpot }

/// One inspectable insight row in the evidence ledger bottom sheet.
class EvidenceLedgerInspectItem {
  const EvidenceLedgerInspectItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.confidenceBand,
    this.referenceDate,
  });

  final String id;
  final EvidenceLedgerItemKind kind;
  final String title;
  final String subtitle;
  final PatternMatchConfidenceBand confidenceBand;
  final DateTime? referenceDate;

  String get kindLabel => switch (kind) {
    EvidenceLedgerItemKind.belief => 'Belief',
    EvidenceLedgerItemKind.contradiction => 'Contradiction',
    EvidenceLedgerItemKind.blindSpot => 'Blind spot',
  };

  String get searchableText => '$title $subtitle ${kindLabel.toLowerCase()}';
}

class EvidenceLedgerCounts {
  const EvidenceLedgerCounts({
    required this.citableFactCount,
    required this.entryCount,
  });

  const EvidenceLedgerCounts.empty()
      : citableFactCount = 0,
        entryCount = 0;

  final int citableFactCount;
  final int entryCount;

  bool get isEmpty => citableFactCount == 0 && entryCount == 0;
}

enum EvidenceLedgerDateFilter { all, last7Days, last30Days, last90Days }