import '../archive_explanations/explanation_models.dart';

/// Kind of day-level archive discovery.
enum DailyDiscoveryType {
  newBelief,
  beliefWeakening,
  beliefStrengthening,
  contradictionEmerging,
  contradictionResolved,
  themeSpike,
  themeDecline,
  chapterTransition,
  emotionalShift,
  unexpectedCorrelation,
}

/// Evidence-backed discovery surfaced on Archive when the journal grows.
class DailyDiscovery {
  const DailyDiscovery({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.whyItMatters,
    required this.evidenceIds,
    required this.confidence,
    required this.createdAt,
    required this.insightRef,
  });

  final String id;
  final DailyDiscoveryType type;
  final String title;
  final String summary;
  final String whyItMatters;
  final List<String> evidenceIds;
  final double confidence;
  final DateTime createdAt;
  final ArchiveInsightRef insightRef;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'summary': summary,
        'whyItMatters': whyItMatters,
        'evidenceIds': evidenceIds,
        'confidence': confidence,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'insightRefId': insightRef.id,
        'insightKind': insightRef.kind.name,
        'themeKey': insightRef.themeKey,
        'chapterId': insightRef.chapterId,
        'entryIdA': insightRef.entryIdA,
        'entryIdB': insightRef.entryIdB,
        'surpriseIndex': insightRef.surpriseIndex,
        'challengeIndex': insightRef.challengeIndex,
        'askPrompt': insightRef.askPrompt,
      };

  static DailyDiscovery? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final type = DailyDiscoveryType.values.asNameMap()[json['type']?.toString()];
    if (type == null) return null;
    final ref = _insightRefFromJson(json);
    if (ref == null) return null;
    final evidence = (json['evidenceIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    if (evidence.isEmpty) return null;

    return DailyDiscovery(
      id: id,
      type: type,
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      whyItMatters: json['whyItMatters']?.toString() ?? '',
      evidenceIds: evidence,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      insightRef: ref,
    );
  }

  static ArchiveInsightRef? _insightRefFromJson(Map<String, dynamic> json) {
    final refId = json['insightRefId']?.toString();
    if (refId == null || refId.isEmpty) return null;
    final parsed = ArchiveInsightRef.parseRouteId(refId);
    if (parsed != null) return parsed;
    final kindName = json['insightKind']?.toString();
    final kind = ArchiveInsightKind.values.asNameMap()[kindName];
    if (kind == null) return null;
    return ArchiveInsightRef(
      id: refId,
      kind: kind,
      themeKey: json['themeKey']?.toString(),
      chapterId: json['chapterId']?.toString(),
      entryIdA: json['entryIdA']?.toString(),
      entryIdB: json['entryIdB']?.toString(),
      surpriseIndex: (json['surpriseIndex'] as num?)?.toInt(),
      challengeIndex: (json['challengeIndex'] as num?)?.toInt(),
      askPrompt: json['askPrompt']?.toString(),
    );
  }
}

/// Snapshot of archive signals used to detect day-over-day change.
class DailyDiscoveryBaseline {
  const DailyDiscoveryBaseline({
    required this.lastEntryId,
    required this.entryCount,
    required this.belief,
    required this.themeCounts,
    required this.contradictionIds,
    required this.latestChapterId,
    required this.avgEmotionalIntensity,
    required this.beliefStrengthPercent,
  });

  final String lastEntryId;
  final int entryCount;
  final String? belief;
  final Map<String, int> themeCounts;
  final List<String> contradictionIds;
  final String? latestChapterId;
  final double? avgEmotionalIntensity;
  final int beliefStrengthPercent;

  Map<String, dynamic> toJson() => {
        'lastEntryId': lastEntryId,
        'entryCount': entryCount,
        'belief': belief,
        'themeCounts': themeCounts,
        'contradictionIds': contradictionIds,
        'latestChapterId': latestChapterId,
        'avgEmotionalIntensity': avgEmotionalIntensity,
        'beliefStrengthPercent': beliefStrengthPercent,
      };

  static DailyDiscoveryBaseline? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lastId = json['lastEntryId']?.toString() ?? '';
    return DailyDiscoveryBaseline(
      lastEntryId: lastId,
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      belief: json['belief']?.toString(),
      themeCounts: (json['themeCounts'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          {},
      contradictionIds: (json['contradictionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      latestChapterId: json['latestChapterId']?.toString(),
      avgEmotionalIntensity: (json['avgEmotionalIntensity'] as num?)?.toDouble(),
      beliefStrengthPercent:
          (json['beliefStrengthPercent'] as num?)?.toInt() ?? 0,
    );
  }
}
