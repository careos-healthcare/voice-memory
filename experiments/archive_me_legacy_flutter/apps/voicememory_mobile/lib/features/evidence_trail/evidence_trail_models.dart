/// Evidence Trail V1 — bottom-sheet payload (no AI).
enum EvidenceSourceRole { supporting, contradicting, related }

class EvidenceConfidenceFactor {
  const EvidenceConfidenceFactor({required this.label, required this.value});

  final String label;
  final String value;
}

class EvidenceTrailSource {
  const EvidenceTrailSource({
    required this.entryId,
    required this.recordedAt,
    required this.excerpt,
    this.role = EvidenceSourceRole.supporting,
    this.startUtf16,
    this.endUtf16,
    this.sourceType,
  });

  final String entryId;
  final DateTime recordedAt;
  final String excerpt;
  final EvidenceSourceRole role;
  final int? startUtf16;
  final int? endUtf16;
  final String? sourceType;
}

/// What the evidence sheet displays for one archive conclusion.
class EvidenceTrailPayload {
  const EvidenceTrailPayload({
    required this.title,
    required this.whySummary,
    required this.evidenceCount,
    required this.sources,
    this.confidencePercent,
    this.confidenceFactors = const [],
  });

  final String title;
  final String whySummary;
  final int evidenceCount;
  final int? confidencePercent;
  final List<EvidenceConfidenceFactor> confidenceFactors;
  final List<EvidenceTrailSource> sources;

  bool get hasSources => sources.isNotEmpty;
}
