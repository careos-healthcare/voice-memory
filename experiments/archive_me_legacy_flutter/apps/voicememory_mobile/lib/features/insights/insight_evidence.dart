/// Single cited line from a reflection — no insight without at least one.
class InsightEvidenceLine {
  const InsightEvidenceLine({
    required this.entryId,
    required this.quote,
    required this.recordedAt,
    this.label,
  });

  final String entryId;
  final String quote;
  final DateTime recordedAt;
  final String? label;
}
