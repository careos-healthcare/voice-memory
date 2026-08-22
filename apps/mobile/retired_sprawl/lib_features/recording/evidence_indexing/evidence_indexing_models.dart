/// Phases for the post-save evidence indexing transition.
enum EvidenceIndexingPhase {
  listening,
  extracting,
  committing,
  complete,
  skipped,
}

/// One citable anchor surfaced during evidence indexing.
class EvidenceIndexingChip {
  const EvidenceIndexingChip({
    required this.category,
    required this.label,
    required this.value,
    this.factType = 'evidence_anchor',
  });

  final String category;
  final String label;
  final String value;
  final String factType;

  String get displayText => '[$category] $value';
}