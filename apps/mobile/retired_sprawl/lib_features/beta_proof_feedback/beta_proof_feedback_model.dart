import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_copy.dart';

enum BetaProofFeedbackSurface {
  timelineProofMoment,
  archiveTimelineSpine,
  firstProofPayoff,
  privateArchiveReportPreview,
}

enum BetaProofFeedbackType { useful, tooVague, alreadyKnew, notRelevant }

extension BetaProofFeedbackSurfaceStorage on BetaProofFeedbackSurface {
  String get storageValue => switch (this) {
    BetaProofFeedbackSurface.timelineProofMoment => 'timeline_proof_moment',
    BetaProofFeedbackSurface.archiveTimelineSpine => 'archive_timeline_spine',
    BetaProofFeedbackSurface.firstProofPayoff => 'first_proof_payoff',
    BetaProofFeedbackSurface.privateArchiveReportPreview =>
      'private_archive_report_preview',
  };

  String get analyticsValue => storageValue;
}

extension BetaProofFeedbackTypeStorage on BetaProofFeedbackType {
  String get storageValue => switch (this) {
    BetaProofFeedbackType.useful => 'useful',
    BetaProofFeedbackType.tooVague => 'too_vague',
    BetaProofFeedbackType.alreadyKnew => 'already_knew',
    BetaProofFeedbackType.notRelevant => 'not_relevant',
  };

  String get analyticsValue => storageValue;

  String get diagnosticsLabel => BetaProofFeedbackCopy.labelFor(this);
}

/// Local-only beta proof feedback for one surface/day.
class BetaProofFeedbackRecord {
  const BetaProofFeedbackRecord({
    this.feedbackType,
    this.dateKey,
    this.surface,
    this.entryCount,
    this.answeredAt,
  });

  factory BetaProofFeedbackRecord.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return BetaProofFeedbackRecord(
      feedbackType: _typeFromRaw(json['feedbackType'] as String?),
      dateKey: json['dateKey'] is String ? json['dateKey'] as String : null,
      surface: _surfaceFromRaw(json['surface'] as String?),
      entryCount: json['entryCount'] is int ? json['entryCount'] as int : null,
      answeredAt: _timestampFromRaw(json['answeredAt'] as String?),
    );
  }

  static const empty = BetaProofFeedbackRecord();

  final BetaProofFeedbackType? feedbackType;
  final String? dateKey;
  final BetaProofFeedbackSurface? surface;
  final int? entryCount;
  final DateTime? answeredAt;

  bool get answered => feedbackType != null;

  Map<String, dynamic> toJson() => {
    if (feedbackType != null) 'feedbackType': feedbackType!.storageValue,
    if (dateKey != null) 'dateKey': dateKey,
    if (surface != null) 'surface': surface!.storageValue,
    if (entryCount != null) 'entryCount': entryCount,
    if (answeredAt != null) 'answeredAt': answeredAt!.toUtc().toIso8601String(),
  };

  static BetaProofFeedbackType? _typeFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return BetaProofFeedbackType.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => BetaProofFeedbackType.useful,
    );
  }

  static BetaProofFeedbackSurface? _surfaceFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return BetaProofFeedbackSurface.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => BetaProofFeedbackSurface.timelineProofMoment,
    );
  }

  static DateTime? _timestampFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}