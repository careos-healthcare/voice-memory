import '../archive_explanations/explanation_models.dart';

/// One active evidence-backed challenge for Discover.
class ArchiveChallenge {
  const ArchiveChallenge({
    required this.id,
    required this.headline,
    required this.body,
    required this.evidenceEntryIds,
    required this.confidence,
    required this.insightRef,
    required this.detectedAt,
  });

  final String id;
  final String headline;
  final String body;
  final List<String> evidenceEntryIds;
  final int confidence;
  final ArchiveInsightRef insightRef;
  final DateTime detectedAt;

  int get evidenceCount => evidenceEntryIds.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'headline': headline,
    'body': body,
    'evidenceEntryIds': evidenceEntryIds,
    'confidence': confidence,
    'insightRefId': insightRef.id,
    'insightKind': insightRef.kind.name,
    'challengeIndex': insightRef.challengeIndex,
    'askPrompt': insightRef.askPrompt,
    'detectedAt': detectedAt.toUtc().toIso8601String(),
  };

  static ArchiveChallenge? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id']?.toString() ?? '';
    final headline = json['headline']?.toString().trim() ?? '';
    if (id.isEmpty || headline.isEmpty) return null;
    final evidence =
        (json['evidenceEntryIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    if (evidence.isEmpty) return null;
    final confidence = (json['confidence'] as num?)?.toInt() ?? 0;
    final refId = json['insightRefId']?.toString();
    ArchiveInsightRef? ref;
    if (refId != null && refId.isNotEmpty) {
      ref = ArchiveInsightRef.parseRouteId(refId);
      if (ref == null && json['challengeIndex'] != null) {
        ref = ArchiveInsightRef.challenge(
          (json['challengeIndex'] as num).toInt(),
        );
      }
    }
    if (ref == null) {
      final kind = ArchiveInsightKind.values
          .asNameMap()[json['insightKind']?.toString()];
      if (kind == ArchiveInsightKind.askArchive) {
        ref = ArchiveInsightRef.askArchive(json['askPrompt']?.toString() ?? '');
      }
    }
    ref ??= ArchiveInsightRef.challenge(0);

    return ArchiveChallenge(
      id: id,
      headline: headline,
      body: json['body']?.toString() ?? headline,
      evidenceEntryIds: evidence,
      confidence: confidence,
      insightRef: ref,
      detectedAt:
          DateTime.tryParse(json['detectedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
