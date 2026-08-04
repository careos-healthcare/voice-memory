/// Local feedback choice for archive insights — never synced.
///
/// The first four values preserve the original archive-feedback wire format.
/// The auditable conclusion values are shared by Record, Archive and Changes.
enum InsightFeedbackChoice {
  fits,
  notQuite,
  tooEarly,
  saveAsWatchTheme,
  accurate,
  wrongAngle,
  tooGeneric,
  hide,
}

/// Safe insight surface type — metadata only.
enum InsightFeedbackType {
  thenVsNow,
  archiveClarity,
  weeklyReview,
  auditableConclusion,
}

/// One local feedback record — no raw journal text.
class InsightFeedbackRecord {
  const InsightFeedbackRecord({
    required this.insightId,
    required this.insightType,
    required this.choice,
    required this.createdAt,
    required this.sourceRoute,
    this.templateId,
    this.conclusionKind,
    this.evidenceEntryIds = const [],
    this.correctionNote,
  });

  final String insightId;
  final InsightFeedbackType insightType;
  final InsightFeedbackChoice choice;
  final DateTime createdAt;
  final String sourceRoute;
  final String? templateId;
  final String? conclusionKind;
  final List<String> evidenceEntryIds;

  /// Private local interpretation context. Never include this in analytics.
  final String? correctionNote;

  Map<String, dynamic> toJson() => {
    'insightId': insightId,
    'insightType': insightType.name,
    'choice': choice.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sourceRoute': sourceRoute,
    if (templateId?.trim().isNotEmpty == true) 'templateId': templateId,
    if (conclusionKind?.trim().isNotEmpty == true)
      'conclusionKind': conclusionKind,
    if (evidenceEntryIds.isNotEmpty) 'evidenceEntryIds': evidenceEntryIds,
    if (correctionNote?.trim().isNotEmpty == true)
      'correctionNote': correctionNote!.trim(),
  };

  factory InsightFeedbackRecord.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'] as String?;
    return InsightFeedbackRecord(
      insightId: json['insightId'] as String? ?? '',
      insightType: InsightFeedbackType.values.firstWhere(
        (type) => type.name == json['insightType'],
        orElse: () => InsightFeedbackType.thenVsNow,
      ),
      choice: InsightFeedbackChoice.values.firstWhere(
        (choice) => choice.name == json['choice'],
        orElse: () => InsightFeedbackChoice.fits,
      ),
      createdAt: createdRaw != null
          ? DateTime.parse(createdRaw).toLocal()
          : DateTime.now(),
      sourceRoute: json['sourceRoute'] as String? ?? '',
      templateId: json['templateId']?.toString(),
      conclusionKind: json['conclusionKind']?.toString(),
      evidenceEntryIds: (json['evidenceEntryIds'] as List? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      correctionNote: json['correctionNote']?.toString(),
    );
  }

  bool hasMateriallyNewEvidence(Iterable<String> candidateEntryIds) {
    final prior = evidenceEntryIds.toSet();
    return candidateEntryIds.any((entryId) => !prior.contains(entryId));
  }
}

/// Derived local trust summary — counts only.
class InsightFeedbackSummary {
  const InsightFeedbackSummary({
    required this.latestRecord,
    required this.fitsCount,
    required this.notQuiteCount,
    required this.tooEarlyCount,
    required this.saveAsWatchThemeCount,
    required this.trustSummaryLabel,
  });

  final InsightFeedbackRecord? latestRecord;
  final int fitsCount;
  final int notQuiteCount;
  final int tooEarlyCount;
  final int saveAsWatchThemeCount;
  final String trustSummaryLabel;

  static const empty = InsightFeedbackSummary(
    latestRecord: null,
    fitsCount: 0,
    notQuiteCount: 0,
    tooEarlyCount: 0,
    saveAsWatchThemeCount: 0,
    trustSummaryLabel: '',
  );
}

/// Deterministic insight ids — safe strings only.
abstract final class InsightFeedbackIds {
  InsightFeedbackIds._();

  static const thenVsNow = 'then_vs_now';
  static const archiveClarity = 'archive_clarity';
  static const weeklyReview = 'weekly_review';
}
