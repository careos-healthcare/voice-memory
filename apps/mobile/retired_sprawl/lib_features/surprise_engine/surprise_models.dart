import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';

/// Priority order for Surprise Pipeline V1 (lowest index wins).
enum SurpriseType {
  archiveChangedMind,
  confidenceChangedSharply,
  newContradiction,
  unexpectedThemeRise,
  themeDisappearance,
  newLifeChapter,
  emotionalShift,
}

/// One surfaced surprise — only one shown at a time on Archive home.
class ArchiveSurprise {
  const ArchiveSurprise({
    required this.id,
    required this.type,
    required this.headline,
    required this.why,
    required this.evidenceIds,
    required this.insightRef,
    required this.createdAt,
    this.chapterId,
    this.themeKey,
  });

  final String id;
  final SurpriseType type;
  final String headline;
  final String why;
  final List<String> evidenceIds;
  final ArchiveInsightRef insightRef;
  final DateTime createdAt;
  final String? chapterId;
  final String? themeKey;

  bool get supportsTimeline =>
      type == SurpriseType.confidenceChangedSharply ||
      type == SurpriseType.archiveChangedMind ||
      type == SurpriseType.newContradiction ||
      type == SurpriseType.newLifeChapter;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'headline': headline,
    'why': why,
    'evidenceIds': evidenceIds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'chapterId': chapterId,
    'themeKey': themeKey,
    'insightRefId': insightRef.id,
    'insightKind': insightRef.kind.name,
    'themeKeyRef': insightRef.themeKey,
    'chapterIdRef': insightRef.chapterId,
    'entryIdA': insightRef.entryIdA,
    'entryIdB': insightRef.entryIdB,
    'surpriseIndex': insightRef.surpriseIndex,
    'challengeIndex': insightRef.challengeIndex,
    'askPrompt': insightRef.askPrompt,
  };

  static ArchiveSurprise? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final type = SurpriseType.values.asNameMap()[json['type']?.toString()];
    if (type == null) return null;
    final evidence =
        (json['evidenceIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    if (evidence.isEmpty) return null;

    final ref = _insightRefFromJson(json);
    if (ref == null) return null;

    final createdRaw = json['createdAt']?.toString();
    final createdAt = createdRaw != null
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.now();

    return ArchiveSurprise(
      id: id,
      type: type,
      headline: json['headline']?.toString() ?? '',
      why: json['why']?.toString() ?? '',
      evidenceIds: evidence,
      insightRef: ref,
      createdAt: createdAt,
      chapterId: json['chapterId']?.toString(),
      themeKey: json['themeKey']?.toString(),
    );
  }

  static ArchiveInsightRef? _insightRefFromJson(Map<String, dynamic> json) {
    final kind = ArchiveInsightKind.values
        .asNameMap()[json['insightKind']?.toString()];
    if (kind == null) return null;
    return ArchiveInsightRef(
      id: json['insightRefId']?.toString() ?? 'belief',
      kind: kind,
      themeKey: json['themeKeyRef']?.toString(),
      chapterId: json['chapterIdRef']?.toString(),
      entryIdA: json['entryIdA']?.toString(),
      entryIdB: json['entryIdB']?.toString(),
      surpriseIndex: (json['surpriseIndex'] as num?)?.toInt(),
      challengeIndex: (json['challengeIndex'] as num?)?.toInt(),
      askPrompt: json['askPrompt']?.toString(),
    );
  }
}

/// Persisted surprise engagement — [lastSurpriseSeenAt], [lastSurpriseType], [lastSurpriseEvidence].
class SurpriseEngagementState {
  const SurpriseEngagementState({
    this.lastSurpriseSeenAt,
    this.lastSurpriseType,
    this.lastSurpriseEvidence = const [],
    this.lastDismissedSurpriseId,
    this.activeSurprise,
    this.lastEntryIdWhenSurprised,
  });

  final DateTime? lastSurpriseSeenAt;
  final SurpriseType? lastSurpriseType;
  final List<String> lastSurpriseEvidence;
  final String? lastDismissedSurpriseId;
  final ArchiveSurprise? activeSurprise;
  final String? lastEntryIdWhenSurprised;
}