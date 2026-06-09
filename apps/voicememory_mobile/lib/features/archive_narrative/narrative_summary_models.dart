/// Evidence-backed personal development narrative from archive signals.
class NarrativeSummary {
  const NarrativeSummary({
    required this.summary,
    required this.supportingBeliefs,
    required this.supportingThemes,
    required this.supportingRecordingIds,
    required this.hasMinimumArchiveEvidence,
    required this.evidenceReflectionCount,
  });

  final String summary;
  final List<String> supportingBeliefs;
  final List<String> supportingThemes;
  final List<String> supportingRecordingIds;
  final bool hasMinimumArchiveEvidence;
  final int evidenceReflectionCount;

  bool get hasNarrative =>
      hasMinimumArchiveEvidence && summary.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'summary': summary,
        'supportingBeliefs': supportingBeliefs,
        'supportingThemes': supportingThemes,
        'supportingRecordingIds': supportingRecordingIds,
        'hasMinimumArchiveEvidence': hasMinimumArchiveEvidence,
        'evidenceReflectionCount': evidenceReflectionCount,
      };

  static NarrativeSummary empty({int evidenceCount = 0}) {
    return NarrativeSummary(
      summary: '',
      supportingBeliefs: const [],
      supportingThemes: const [],
      supportingRecordingIds: const [],
      hasMinimumArchiveEvidence: false,
      evidenceReflectionCount: evidenceCount,
    );
  }

  static NarrativeSummary fromJson(Map<String, dynamic>? json) {
    if (json == null) return NarrativeSummary.empty();
    return NarrativeSummary(
      summary: json['summary']?.toString().trim() ?? '',
      supportingBeliefs: (json['supportingBeliefs'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      supportingThemes: (json['supportingThemes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      supportingRecordingIds:
          (json['supportingRecordingIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList(),
      hasMinimumArchiveEvidence: json['hasMinimumArchiveEvidence'] == true,
      evidenceReflectionCount:
          (json['evidenceReflectionCount'] as num?)?.toInt() ?? 0,
    );
  }
}
