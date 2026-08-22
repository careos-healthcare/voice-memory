import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';

/// User-facing lifecycle of a signal review payoff.
enum SignalReviewStatus { draft, ready, confirmed, corrected, watching }

extension SignalReviewStatusIds on SignalReviewStatus {
  String get id => name;

  static SignalReviewStatus? fromId(String? raw) {
    if (raw == null) return null;
    for (final s in SignalReviewStatus.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// ArchiveMe review when a signal journey reaches enough supporting evidence.
class SignalReview {
  const SignalReview({
    required this.id,
    required this.journeyId,
    required this.signalTitle,
    required this.reviewStatus,
    required this.evidenceCount,
    required this.whatRepeated,
    required this.whatChanged,
    required this.evidenceLines,
    required this.possibleContradictions,
    required this.whatToWatchNext,
    required this.nextEvidencePrompt,
    required this.createdAt,
    required this.updatedAt,
    this.needsMoreEvidence = false,
    this.correctionTitle,
    this.loopModeId,
    this.loopTitle,
    this.reviewSubtitle,
    this.whatItSeemedToCost,
    this.commonTrigger,
    this.whatWouldProveThisWrong,
    this.reviewConfidenceLabel,
  });

  final String id;
  final String journeyId;
  final String signalTitle;
  final SignalReviewStatus reviewStatus;
  final int evidenceCount;
  final String whatRepeated;
  final String whatChanged;
  final List<String> evidenceLines;
  final String possibleContradictions;
  final String whatToWatchNext;
  final String nextEvidencePrompt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool needsMoreEvidence;
  final String? correctionTitle;
  final String? loopModeId;
  final String? loopTitle;
  final String? reviewSubtitle;
  final String? whatItSeemedToCost;
  final String? commonTrigger;
  final String? whatWouldProveThisWrong;
  final String? reviewConfidenceLabel;

  bool get isCapacityLoopReview => loopModeId == LoopModeIds.capacityYes;

  bool get isProveEnoughLoopReview => loopModeId == LoopModeIds.proveEnough;

  bool get isLoopSpecificReview =>
      isCapacityLoopReview || isProveEnoughLoopReview;

  bool get isShowable =>
      reviewStatus != SignalReviewStatus.draft || needsMoreEvidence;

  bool get isActionable =>
      reviewStatus == SignalReviewStatus.ready ||
      reviewStatus == SignalReviewStatus.watching;

  Map<String, dynamic> toJson() => {
    'id': id,
    'journeyId': journeyId,
    'signalTitle': signalTitle,
    'reviewStatus': reviewStatus.id,
    'evidenceCount': evidenceCount,
    'whatRepeated': whatRepeated,
    'whatChanged': whatChanged,
    'evidenceLines': evidenceLines,
    'possibleContradictions': possibleContradictions,
    'whatToWatchNext': whatToWatchNext,
    'nextEvidencePrompt': nextEvidencePrompt,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'needsMoreEvidence': needsMoreEvidence,
    if (correctionTitle != null) 'correctionTitle': correctionTitle,
    if (loopModeId != null) 'loopModeId': loopModeId,
    if (loopTitle != null) 'loopTitle': loopTitle,
    if (reviewSubtitle != null) 'reviewSubtitle': reviewSubtitle,
    if (whatItSeemedToCost != null) 'whatItSeemedToCost': whatItSeemedToCost,
    if (commonTrigger != null) 'commonTrigger': commonTrigger,
    if (whatWouldProveThisWrong != null)
      'whatWouldProveThisWrong': whatWouldProveThisWrong,
    if (reviewConfidenceLabel != null)
      'reviewConfidenceLabel': reviewConfidenceLabel,
  };

  static SignalReview? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final journeyId = map['journeyId'] as String?;
    final signalTitle = map['signalTitle'] as String?;
    final status = SignalReviewStatusIds.fromId(map['reviewStatus'] as String?);
    final createdRaw = map['createdAt'] as String?;
    final updatedRaw = map['updatedAt'] as String?;
    if (id == null ||
        journeyId == null ||
        signalTitle == null ||
        status == null ||
        createdRaw == null ||
        updatedRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw);
    final updatedAt = DateTime.tryParse(updatedRaw);
    if (createdAt == null || updatedAt == null) return null;

    final linesRaw = map['evidenceLines'];
    final evidenceLines = linesRaw is List
        ? linesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return SignalReview(
      id: id,
      journeyId: journeyId,
      signalTitle: signalTitle,
      reviewStatus: status,
      evidenceCount: (map['evidenceCount'] as num?)?.toInt() ?? 0,
      whatRepeated: map['whatRepeated'] as String? ?? '',
      whatChanged: map['whatChanged'] as String? ?? '',
      evidenceLines: evidenceLines,
      possibleContradictions: map['possibleContradictions'] as String? ?? '',
      whatToWatchNext: map['whatToWatchNext'] as String? ?? '',
      nextEvidencePrompt: map['nextEvidencePrompt'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      needsMoreEvidence: map['needsMoreEvidence'] == true,
      correctionTitle: map['correctionTitle'] as String?,
      loopModeId: map['loopModeId'] as String?,
      loopTitle: map['loopTitle'] as String?,
      reviewSubtitle: map['reviewSubtitle'] as String?,
      whatItSeemedToCost: map['whatItSeemedToCost'] as String?,
      commonTrigger: map['commonTrigger'] as String?,
      whatWouldProveThisWrong: map['whatWouldProveThisWrong'] as String?,
      reviewConfidenceLabel: map['reviewConfidenceLabel'] as String?,
    );
  }

  SignalReview copyWith({
    String? id,
    String? journeyId,
    String? signalTitle,
    SignalReviewStatus? reviewStatus,
    int? evidenceCount,
    String? whatRepeated,
    String? whatChanged,
    List<String>? evidenceLines,
    String? possibleContradictions,
    String? whatToWatchNext,
    String? nextEvidencePrompt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsMoreEvidence,
    String? correctionTitle,
    String? loopModeId,
    String? loopTitle,
    String? reviewSubtitle,
    String? whatItSeemedToCost,
    String? commonTrigger,
    String? whatWouldProveThisWrong,
    String? reviewConfidenceLabel,
  }) {
    return SignalReview(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      signalTitle: signalTitle ?? this.signalTitle,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      whatRepeated: whatRepeated ?? this.whatRepeated,
      whatChanged: whatChanged ?? this.whatChanged,
      evidenceLines: evidenceLines ?? this.evidenceLines,
      possibleContradictions:
          possibleContradictions ?? this.possibleContradictions,
      whatToWatchNext: whatToWatchNext ?? this.whatToWatchNext,
      nextEvidencePrompt: nextEvidencePrompt ?? this.nextEvidencePrompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsMoreEvidence: needsMoreEvidence ?? this.needsMoreEvidence,
      correctionTitle: correctionTitle ?? this.correctionTitle,
      loopModeId: loopModeId ?? this.loopModeId,
      loopTitle: loopTitle ?? this.loopTitle,
      reviewSubtitle: reviewSubtitle ?? this.reviewSubtitle,
      whatItSeemedToCost: whatItSeemedToCost ?? this.whatItSeemedToCost,
      commonTrigger: commonTrigger ?? this.commonTrigger,
      whatWouldProveThisWrong:
          whatWouldProveThisWrong ?? this.whatWouldProveThisWrong,
      reviewConfidenceLabel:
          reviewConfidenceLabel ?? this.reviewConfidenceLabel,
    );
  }
}