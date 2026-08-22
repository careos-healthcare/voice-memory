/// Evidence Method insight payload returned by `/api/insights/evidence`.
class EvidenceInsight {
  const EvidenceInsight({
    required this.id,
    required this.insightText,
    required this.confidenceBand,
    required this.citedEntryIds,
    this.kind,
  });

  factory EvidenceInsight.fromJson(Map<String, dynamic> json) {
    final cited = json['citedEntryIds'];
    return EvidenceInsight(
      id: json['id'] as String? ?? '',
      insightText: json['insightText'] as String? ?? '',
      confidenceBand: json['confidenceBand'] as String? ?? 'weak',
      kind: json['kind'] as String?,
      citedEntryIds: cited is List
          ? cited.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String insightText;
  final String confidenceBand;
  final String? kind;
  final List<String> citedEntryIds;
}