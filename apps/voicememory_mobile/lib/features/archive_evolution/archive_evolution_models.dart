import '../archive_explanations/explanation_models.dart';

/// Living archive evolution — one active event at a time.
enum ArchiveEvolutionKind {
  archiveChangedMind,
  confidenceIncreased,
  confidenceDecreased,
  beliefUnderReview,
  newPatternEmerging,
  oldPatternFading,
}

class ArchiveEvolution {
  const ArchiveEvolution({
    required this.id,
    required this.kind,
    required this.sectionHeadline,
    required this.headline,
    required this.summary,
    required this.confidence,
    required this.evidenceIds,
    required this.insightRef,
    required this.createdAt,
  });

  final String id;
  final ArchiveEvolutionKind kind;
  final String sectionHeadline;
  final String headline;
  final String summary;
  final int confidence;
  final List<String> evidenceIds;
  final ArchiveInsightRef insightRef;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'sectionHeadline': sectionHeadline,
        'headline': headline,
        'summary': summary,
        'confidence': confidence,
        'evidenceIds': evidenceIds,
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

  static ArchiveEvolution? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final kind = ArchiveEvolutionKind.values.asNameMap()[json['kind']?.toString()];
    if (kind == null) return null;
    final ref = _insightRefFromJson(json);
    if (ref == null) return null;
    final evidence = (json['evidenceIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    if (evidence.isEmpty) return null;

    return ArchiveEvolution(
      id: id,
      kind: kind,
      sectionHeadline: json['sectionHeadline']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.round() ?? 60,
      evidenceIds: evidence,
      insightRef: ref,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static ArchiveInsightRef? _insightRefFromJson(Map<String, dynamic> json) {
    final kind = ArchiveInsightKind.values
        .asNameMap()[json['insightKind']?.toString()];
    if (kind == null) return null;
    return ArchiveInsightRef(
      id: json['insightRefId']?.toString() ?? 'belief',
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

/// Persisted for future push notifications (not sent in V1).
class PendingEvolutionNotification {
  const PendingEvolutionNotification({
    required this.evolution,
    required this.recordedAt,
    this.delivered = false,
  });

  final ArchiveEvolution evolution;
  final DateTime recordedAt;
  final bool delivered;

  Map<String, dynamic> toJson() => {
        'evolution': evolution.toJson(),
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'delivered': delivered,
      };

  static PendingEvolutionNotification? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final evo = ArchiveEvolution.fromJson(
      json['evolution'] is Map<String, dynamic>
          ? json['evolution'] as Map<String, dynamic>
          : json['evolution'] is Map
              ? Map<String, dynamic>.from(json['evolution'] as Map)
              : null,
    );
    if (evo == null) return null;
    return PendingEvolutionNotification(
      evolution: evo,
      recordedAt:
          DateTime.tryParse(json['recordedAt']?.toString() ?? '') ?? DateTime.now(),
      delivered: json['delivered'] == true,
    );
  }
}

class ArchiveEvolutionState {
  const ArchiveEvolutionState({
    this.activeEvolution,
    this.pendingEvolutionEvent,
    this.lastDismissedEvolutionId,
    this.lastEntryIdWhenEvolved,
    this.lastArchiveUpdateAt,
  });

  final ArchiveEvolution? activeEvolution;
  final PendingEvolutionNotification? pendingEvolutionEvent;
  final String? lastDismissedEvolutionId;
  final String? lastEntryIdWhenEvolved;
  final DateTime? lastArchiveUpdateAt;
}
