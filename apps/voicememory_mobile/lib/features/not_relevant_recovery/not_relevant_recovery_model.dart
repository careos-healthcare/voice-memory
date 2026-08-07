import 'not_relevant_recovery_copy.dart';

/// Resolved not-relevant recovery card — metadata only, no journal text.
class NotRelevantRecoveryResult {
  const NotRelevantRecoveryResult({
    required this.shouldShow,
    required this.proofKey,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasFreshReturn,
    required this.title,
    required this.body,
    required this.correctionLine,
    required this.returnLine,
    required this.returnedAfterCorrectionLine,
  });

  final bool shouldShow;
  final String proofKey;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasFreshReturn;
  final String title;
  final String body;
  final String correctionLine;
  final String returnLine;
  final String returnedAfterCorrectionLine;

  factory NotRelevantRecoveryResult.hidden({
    required String source,
    int entryCount = 0,
  }) => NotRelevantRecoveryResult(
    shouldShow: false,
    proofKey: '',
    entryCount: entryCount,
    source: source,
    hasConfirmedRepeat: false,
    hasFreshReturn: false,
    title: NotRelevantRecoveryCopy.title,
    body: NotRelevantRecoveryCopy.body,
    correctionLine: NotRelevantRecoveryCopy.correctionLine,
    returnLine: NotRelevantRecoveryCopy.returnLine,
    returnedAfterCorrectionLine:
        NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
  );
}

class NotRelevantRecoveryRecord {
  const NotRelevantRecoveryRecord({
    this.actionType,
    this.proofKey,
    this.entryCount,
    this.answeredAt,
  });

  static const empty = NotRelevantRecoveryRecord();

  final NotRelevantRecoveryActionType? actionType;
  final String? proofKey;
  final int? entryCount;
  final DateTime? answeredAt;

  bool get answered => actionType != null;

  Map<String, dynamic> toJson() => {
    if (actionType != null) 'actionType': actionType!.storageValue,
    if (proofKey != null) 'proofKey': proofKey,
    if (entryCount != null) 'entryCount': entryCount,
    if (answeredAt != null) 'answeredAt': answeredAt!.toUtc().toIso8601String(),
  };

  factory NotRelevantRecoveryRecord.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return NotRelevantRecoveryRecord(
      actionType: _actionFromRaw(json['actionType'] as String?),
      proofKey: json['proofKey'] is String ? json['proofKey'] as String : null,
      entryCount: json['entryCount'] is int ? json['entryCount'] as int : null,
      answeredAt: _timestampFromRaw(json['answeredAt'] as String?),
    );
  }

  static NotRelevantRecoveryActionType? _actionFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return NotRelevantRecoveryActionType.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => NotRelevantRecoveryActionType.keepAsBackground,
    );
  }

  static DateTime? _timestampFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
