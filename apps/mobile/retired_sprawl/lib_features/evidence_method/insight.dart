import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// A ledger-backed quote cited as evidence for an insight.
class CitedEntry {
  const CitedEntry({
    required this.entryId,
    required this.rawText,
    required this.createdAt,
    this.audioId,
    this.startTimestampMs,
    this.endTimestampMs,
    this.chunkId,
  });

  factory CitedEntry.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] as String?;
    return CitedEntry(
      entryId: json['entryId'] as String? ?? '',
      rawText: json['rawText'] as String? ?? json['raw_text'] as String? ?? '',
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      audioId: json['audioId'] as String? ?? json['audio_id'] as String?,
      startTimestampMs: _readInt(json['startTimestampMs'] ?? json['start_timestamp_ms']),
      endTimestampMs: _readInt(json['endTimestampMs'] ?? json['end_timestamp_ms']),
      chunkId: json['chunkId'] as String? ?? json['chunk_id'] as String?,
    );
  }

  final String entryId;
  final String rawText;
  final DateTime createdAt;
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

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'rawText': rawText,
    'createdAt': createdAt.toIso8601String(),
    if (audioId != null) 'audioId': audioId,
    if (startTimestampMs != null) 'startTimestampMs': startTimestampMs,
    if (endTimestampMs != null) 'endTimestampMs': endTimestampMs,
    if (chunkId != null) 'chunkId': chunkId,
  };

  CitedEntry copyWith({
    String? entryId,
    String? rawText,
    DateTime? createdAt,
    String? audioId,
    int? startTimestampMs,
    int? endTimestampMs,
    String? chunkId,
  }) {
    return CitedEntry(
      entryId: entryId ?? this.entryId,
      rawText: rawText ?? this.rawText,
      createdAt: createdAt ?? this.createdAt,
      audioId: audioId ?? this.audioId,
      startTimestampMs: startTimestampMs ?? this.startTimestampMs,
      endTimestampMs: endTimestampMs ?? this.endTimestampMs,
      chunkId: chunkId ?? this.chunkId,
    );
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// Evidence Method insight with cited ledger entries.
class Insight {
  const Insight({
    required this.id,
    required this.insightText,
    required this.kind,
    required this.confidenceBand,
    required this.citedEntries,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    final cited = json['citedEntries'] ?? json['cited_entries'];
    final kindName = json['kind'] as String? ?? 'theme';
    final bandName = json['confidenceBand'] as String? ?? 'weak';

    return Insight(
      id: json['id'] as String? ?? '',
      insightText: json['insightText'] as String? ?? '',
      kind: ArchiveInsightKind.values.asNameMap()[kindName] ??
          ArchiveInsightKind.theme,
      confidenceBand:
          PatternMatchConfidenceBand.values.asNameMap()[bandName] ??
          PatternMatchConfidenceBand.weak,
      citedEntries: cited is List
          ? cited
              .whereType<Map<String, dynamic>>()
              .map(CitedEntry.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String insightText;
  final ArchiveInsightKind kind;
  final PatternMatchConfidenceBand confidenceBand;
  final List<CitedEntry> citedEntries;
}