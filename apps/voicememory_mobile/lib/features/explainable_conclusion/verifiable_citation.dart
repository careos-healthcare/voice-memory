/// A user-verifiable source behind an interpretation.
class VerifiableCitation {
  const VerifiableCitation({
    required this.sourceEntryId,
    required this.exactQuote,
    this.audioTimestampMs,
    required this.confidenceScore,
    this.startUtf16,
    this.endUtf16,
  }) : assert(confidenceScore >= 0 && confidenceScore <= 1);

  final String sourceEntryId;
  final String exactQuote;
  final int? audioTimestampMs;
  final double confidenceScore;
  final int? startUtf16;
  final int? endUtf16;

  String get sourceId => sourceEntryId;
  String get excerpt => exactQuote;

  Map<String, dynamic> toJson() => {
    'sourceEntryId': sourceEntryId,
    'entryId': sourceEntryId,
    'exactQuote': exactQuote,
    'quote': exactQuote,
    if (audioTimestampMs != null) 'audioTimestampMs': audioTimestampMs,
    'confidenceScore': confidenceScore,
    'startUtf16': startUtf16 ?? 0,
    'endUtf16': endUtf16 ?? exactQuote.length,
    'role': 'support',
  };

  static VerifiableCitation? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final entryId =
        json['sourceEntryId']?.toString() ?? json['entryId']?.toString() ?? '';
    final quote =
        json['exactQuote']?.toString() ?? json['quote']?.toString() ?? '';
    final confidence = json['confidenceScore'];
    if (entryId.isEmpty ||
        quote.isEmpty ||
        confidence is! num ||
        confidence < 0 ||
        confidence > 1) {
      return null;
    }
    return VerifiableCitation(
      sourceEntryId: entryId,
      exactQuote: quote,
      audioTimestampMs: (json['audioTimestampMs'] as num?)?.toInt(),
      confidenceScore: confidence.toDouble(),
      startUtf16: (json['startUtf16'] as num?)?.toInt(),
      endUtf16: (json['endUtf16'] as num?)?.toInt(),
    );
  }
}

/// Compatibility constructor for persisted pre-V1 evidence readers.
class AiEvidenceSource extends VerifiableCitation {
  // Compatibility names intentionally differ from canonical super parameters.
  // ignore: use_super_parameters
  const AiEvidenceSource({
    required String sourceId,
    required String excerpt,
    int? audioTimestampMs,
    double confidenceScore = 1,
    int? startUtf16,
    int? endUtf16,
  }) : super(
         sourceEntryId: sourceId,
         exactQuote: excerpt,
         audioTimestampMs: audioTimestampMs,
         confidenceScore: confidenceScore,
         startUtf16: startUtf16,
         endUtf16: endUtf16,
       );
}
