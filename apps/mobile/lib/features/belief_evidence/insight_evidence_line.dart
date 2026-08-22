/// Single cited line from a saved moment — insight surfaces require at least one.
class InsightEvidenceLine {
  const InsightEvidenceLine({
    required this.entryId,
    required this.quote,
    required this.recordedAt,
    this.label,
    this.audioId,
    this.startTimestampMs,
    this.endTimestampMs,
    this.chunkId,
  });

  final String entryId;
  final String quote;
  final DateTime recordedAt;
  final String? label;
  final String? audioId;
  final int? startTimestampMs;
  final int? endTimestampMs;
  final String? chunkId;

  bool get hasCitationPlayback =>
      audioId != null &&
      audioId!.isNotEmpty &&
      startTimestampMs != null &&
      endTimestampMs != null &&
      endTimestampMs! > startTimestampMs!;

  InsightEvidenceLine copyWith({
    String? entryId,
    String? quote,
    DateTime? recordedAt,
    String? label,
    String? audioId,
    int? startTimestampMs,
    int? endTimestampMs,
    String? chunkId,
  }) {
    return InsightEvidenceLine(
      entryId: entryId ?? this.entryId,
      quote: quote ?? this.quote,
      recordedAt: recordedAt ?? this.recordedAt,
      label: label ?? this.label,
      audioId: audioId ?? this.audioId,
      startTimestampMs: startTimestampMs ?? this.startTimestampMs,
      endTimestampMs: endTimestampMs ?? this.endTimestampMs,
      chunkId: chunkId ?? this.chunkId,
    );
  }
}
