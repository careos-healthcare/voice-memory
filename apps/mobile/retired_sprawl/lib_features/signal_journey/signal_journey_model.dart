/// Lifecycle of a working signal being tested across moments.
enum SignalJourneyStatus {
  collectingEvidence,
  gettingClearer,
  confirmedPattern,
  contradicted,
  archived,
}

extension SignalJourneyStatusIds on SignalJourneyStatus {
  String get id => name;

  static SignalJourneyStatus? fromId(String? raw) {
    if (raw == null) return null;
    for (final s in SignalJourneyStatus.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// Guided evidence collection for one saved read — not confirmed truth.
class SignalJourney {
  const SignalJourney({
    required this.id,
    required this.signalId,
    required this.signalTitle,
    required this.status,
    required this.evidenceCount,
    required this.targetEvidenceCount,
    required this.acceptedReadCount,
    required this.rejectedReadCount,
    required this.contradictionCount,
    required this.startedAt,
    required this.updatedAt,
    required this.nextPrompt,
    this.readId,
    this.categoryId,
    this.wouldConfirm,
    this.wouldChallenge,
    this.evidenceSummary,
    this.supportingMomentIds = const [],
    this.contradictingMomentIds = const [],
    this.unclearMomentIds = const [],
    this.completionAcknowledged = false,
  });

  final String id;
  final String signalId;
  final String signalTitle;
  final SignalJourneyStatus status;
  final int evidenceCount;
  final int targetEvidenceCount;
  final int acceptedReadCount;
  final int rejectedReadCount;
  final int contradictionCount;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String nextPrompt;
  final String? readId;
  final String? categoryId;
  final String? wouldConfirm;
  final String? wouldChallenge;
  final String? evidenceSummary;
  final List<String> supportingMomentIds;
  final List<String> contradictingMomentIds;
  final List<String> unclearMomentIds;
  final bool completionAcknowledged;

  bool get isActive =>
      status != SignalJourneyStatus.archived &&
      status != SignalJourneyStatus.contradicted;

  bool get isConfirmed => status == SignalJourneyStatus.confirmedPattern;

  bool get showCompletion => isConfirmed && !completionAcknowledged;

  int get supportingCount => supportingMomentIds.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'signalId': signalId,
    'signalTitle': signalTitle,
    'status': status.id,
    'evidenceCount': evidenceCount,
    'targetEvidenceCount': targetEvidenceCount,
    'acceptedReadCount': acceptedReadCount,
    'rejectedReadCount': rejectedReadCount,
    'contradictionCount': contradictionCount,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'nextPrompt': nextPrompt,
    if (readId != null) 'readId': readId,
    if (categoryId != null) 'categoryId': categoryId,
    if (wouldConfirm != null) 'wouldConfirm': wouldConfirm,
    if (wouldChallenge != null) 'wouldChallenge': wouldChallenge,
    if (evidenceSummary != null) 'evidenceSummary': evidenceSummary,
    'supportingMomentIds': supportingMomentIds,
    'contradictingMomentIds': contradictingMomentIds,
    'unclearMomentIds': unclearMomentIds,
    'completionAcknowledged': completionAcknowledged,
  };

  static SignalJourney? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final signalId = map['signalId'] as String?;
    final signalTitle = map['signalTitle'] as String?;
    final status = SignalJourneyStatusIds.fromId(map['status'] as String?);
    final startedRaw = map['startedAt'] as String?;
    final updatedRaw = map['updatedAt'] as String?;
    if (id == null ||
        signalId == null ||
        signalTitle == null ||
        status == null ||
        startedRaw == null ||
        updatedRaw == null) {
      return null;
    }
    final startedAt = DateTime.tryParse(startedRaw);
    final updatedAt = DateTime.tryParse(updatedRaw);
    if (startedAt == null || updatedAt == null) return null;

    List<String> ids(String key) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw.map((e) => e.toString()).toList();
    }

    return SignalJourney(
      id: id,
      signalId: signalId,
      signalTitle: signalTitle,
      status: status,
      evidenceCount: (map['evidenceCount'] as num?)?.toInt() ?? 0,
      targetEvidenceCount: (map['targetEvidenceCount'] as num?)?.toInt() ?? 3,
      acceptedReadCount: (map['acceptedReadCount'] as num?)?.toInt() ?? 0,
      rejectedReadCount: (map['rejectedReadCount'] as num?)?.toInt() ?? 0,
      contradictionCount: (map['contradictionCount'] as num?)?.toInt() ?? 0,
      startedAt: startedAt,
      updatedAt: updatedAt,
      nextPrompt: map['nextPrompt'] as String? ?? '',
      readId: map['readId'] as String?,
      categoryId: map['categoryId'] as String?,
      wouldConfirm: map['wouldConfirm'] as String?,
      wouldChallenge: map['wouldChallenge'] as String?,
      evidenceSummary: map['evidenceSummary'] as String?,
      supportingMomentIds: ids('supportingMomentIds'),
      contradictingMomentIds: ids('contradictingMomentIds'),
      unclearMomentIds: ids('unclearMomentIds'),
      completionAcknowledged: map['completionAcknowledged'] == true,
    );
  }

  SignalJourney copyWith({
    String? id,
    String? signalId,
    String? signalTitle,
    SignalJourneyStatus? status,
    int? evidenceCount,
    int? targetEvidenceCount,
    int? acceptedReadCount,
    int? rejectedReadCount,
    int? contradictionCount,
    DateTime? startedAt,
    DateTime? updatedAt,
    String? nextPrompt,
    String? readId,
    String? categoryId,
    String? wouldConfirm,
    String? wouldChallenge,
    String? evidenceSummary,
    List<String>? supportingMomentIds,
    List<String>? contradictingMomentIds,
    List<String>? unclearMomentIds,
    bool? completionAcknowledged,
  }) {
    return SignalJourney(
      id: id ?? this.id,
      signalId: signalId ?? this.signalId,
      signalTitle: signalTitle ?? this.signalTitle,
      status: status ?? this.status,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      targetEvidenceCount: targetEvidenceCount ?? this.targetEvidenceCount,
      acceptedReadCount: acceptedReadCount ?? this.acceptedReadCount,
      rejectedReadCount: rejectedReadCount ?? this.rejectedReadCount,
      contradictionCount: contradictionCount ?? this.contradictionCount,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextPrompt: nextPrompt ?? this.nextPrompt,
      readId: readId ?? this.readId,
      categoryId: categoryId ?? this.categoryId,
      wouldConfirm: wouldConfirm ?? this.wouldConfirm,
      wouldChallenge: wouldChallenge ?? this.wouldChallenge,
      evidenceSummary: evidenceSummary ?? this.evidenceSummary,
      supportingMomentIds: supportingMomentIds ?? this.supportingMomentIds,
      contradictingMomentIds:
          contradictingMomentIds ?? this.contradictingMomentIds,
      unclearMomentIds: unclearMomentIds ?? this.unclearMomentIds,
      completionAcknowledged:
          completionAcknowledged ?? this.completionAcknowledged,
    );
  }
}
