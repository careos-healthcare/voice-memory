/// Hook diagnosis event types.
abstract final class HookDiagnosisEventType {
  HookDiagnosisEventType._();

  static const checkInQuestionRated = 'checkInQuestionRated';
  static const checkInResultRated = 'checkInResultRated';
  static const checkInMissedReason = 'checkInMissedReason';
  static const checkInConfusing = 'checkInConfusing';
  static const checkInResultNotUsefulReason = 'checkInResultNotUsefulReason';
}

/// Why a completed check-in result felt not useful.
abstract final class HookDiagnosisNotUsefulReason {
  HookDiagnosisNotUsefulReason._();

  static const tooVague = 'too_vague';
  static const notAccurate = 'not_accurate';
  static const alreadyKnewThis = 'already_knew_this';
  static const confusing = 'confusing';
}

/// Question / result ratings.
abstract final class HookDiagnosisRating {
  HookDiagnosisRating._();

  static const yes = 'yes';
  static const sortOf = 'sort_of';
  static const notReally = 'not_really';
}

/// Missed check-in reasons.
abstract final class HookDiagnosisMissedReason {
  HookDiagnosisMissedReason._();

  static const forgot = 'forgot';
  static const didNotCare = 'did_not_care';
  static const confusing = 'confusing';
  static const other = 'other';
}

/// Likely failure labels for facilitator export.
abstract final class HookLikelyFailure {
  HookLikelyFailure._();

  static const notEnoughData = 'notEnoughData';
  static const questionNotCompelling = 'questionNotCompelling';
  static const reminderProblem = 'reminderProblem';
  static const comprehensionProblem = 'comprehensionProblem';
  static const resultQualityProblem = 'resultQualityProblem';
  static const working = 'working';
}

class HookDiagnosisEvent {
  const HookDiagnosisEvent({
    required this.id,
    required this.createdAt,
    required this.type,
    this.checkInId,
    this.reason,
    this.rating,
    this.metadata = const {},
  });

  final String id;
  final DateTime createdAt;
  final String type;
  final String? checkInId;
  final String? reason;
  final String? rating;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'type': type,
        if (checkInId != null) 'checkInId': checkInId,
        if (reason != null) 'reason': reason,
        if (rating != null) 'rating': rating,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  static HookDiagnosisEvent? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final createdRaw = map['createdAt'] as String?;
    if (createdRaw == null) return null;
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;
    final type = map['type'] as String?;
    if (type == null || type.isEmpty) return null;
    final metaRaw = map['metadata'];
    final metadata = <String, String>{};
    if (metaRaw is Map) {
      for (final e in metaRaw.entries) {
        metadata['${e.key}'] = '${e.value}';
      }
    }
    return HookDiagnosisEvent(
      id: id,
      createdAt: createdAt,
      type: type,
      checkInId: map['checkInId'] as String?,
      reason: map['reason'] as String?,
      rating: map['rating'] as String?,
      metadata: metadata,
    );
  }
}

class HookDiagnosisSummary {
  const HookDiagnosisSummary({
    required this.checkInsCreated,
    required this.checkInsDueShown,
    required this.checkInsCompleted,
    required this.checkInCompletionRate,
    required this.checkInQuestionRatedUseful,
    required this.checkInQuestionRatedSortOf,
    required this.checkInQuestionRatedNotUseful,
    required this.didNotReturnReasonCounts,
    required this.confusingCount,
    required this.forgotCount,
    required this.didNotCareCount,
    required this.resultUsefulCount,
    required this.resultNotUsefulCount,
    required this.resultSortOfCount,
    required this.likelyFailure,
    required this.examplesOpenedCount,
    required this.checkInClarityCardShownCount,
    required this.checkInMomentRecordedCount,
    required this.notUsefulReasonCounts,
    this.clarityIssueRate,
  });

  final int checkInsCreated;
  final int checkInsDueShown;
  final int checkInsCompleted;
  final double checkInCompletionRate;
  final int checkInQuestionRatedUseful;
  final int checkInQuestionRatedSortOf;
  final int checkInQuestionRatedNotUseful;
  final Map<String, int> didNotReturnReasonCounts;
  final int confusingCount;
  final int forgotCount;
  final int didNotCareCount;
  final int resultUsefulCount;
  final int resultNotUsefulCount;
  final int resultSortOfCount;
  final String likelyFailure;
  final int examplesOpenedCount;
  final int checkInClarityCardShownCount;
  final int checkInMomentRecordedCount;
  final Map<String, int> notUsefulReasonCounts;
  final double? clarityIssueRate;

  int get questionRatedTotal =>
      checkInQuestionRatedUseful +
      checkInQuestionRatedSortOf +
      checkInQuestionRatedNotUseful;

  int get resultRatedTotal =>
      resultUsefulCount + resultSortOfCount + resultNotUsefulCount;

  /// Share of rated questions the user found useful or sort-of useful.
  /// Null when no questions were rated.
  double? get usefulQuestionRate {
    final total = questionRatedTotal;
    if (total == 0) return null;
    return (checkInQuestionRatedUseful + checkInQuestionRatedSortOf) / total;
  }

  /// The strongest negative signal pulling against reminders, or 'none'.
  String get dominantFailureReason {
    final candidates = <String, int>{
      'confusing': confusingCount,
      'didNotCare': didNotCareCount,
      'resultNotUseful': resultNotUsefulCount,
      'questionNotUseful': checkInQuestionRatedNotUseful,
    };
    var topKey = 'none';
    var topVal = 0;
    candidates.forEach((key, value) {
      if (value > topVal) {
        topVal = value;
        topKey = key;
      }
    });
    return topVal == 0 ? 'none' : topKey;
  }
}

/// Computes [HookDiagnosisSummary.likelyFailure] from funnel + diagnosis events.
String computeLikelyFailure(HookDiagnosisSummary summary) {
  if (summary.checkInsCreated == 0 && summary.questionRatedTotal == 0) {
    return HookLikelyFailure.notEnoughData;
  }

  final questionDenom = summary.questionRatedTotal;
  final questionPositiveRate = questionDenom == 0
      ? 0.0
      : (summary.checkInQuestionRatedUseful + summary.checkInQuestionRatedSortOf) /
          questionDenom;

  if (summary.checkInCompletionRate >= 0.4 && questionDenom > 0 && questionPositiveRate >= 0.5) {
    return HookLikelyFailure.working;
  }

  final notCompellingScore =
      summary.checkInQuestionRatedNotUseful + summary.didNotCareCount;
  if (notCompellingScore >= 2 ||
      (summary.checkInQuestionRatedNotUseful >= 1 && summary.didNotCareCount >= 1)) {
    return HookLikelyFailure.questionNotCompelling;
  }

  if (summary.checkInsCreated >= 1 &&
      summary.checkInsDueShown < (summary.checkInsCreated * 0.5).ceil()) {
    return HookLikelyFailure.reminderProblem;
  }

  if (summary.confusingCount >= 1) {
    return HookLikelyFailure.comprehensionProblem;
  }

  if (summary.checkInsCompleted >= 1 &&
      summary.resultNotUsefulCount >= 1 &&
      summary.resultUsefulCount == 0 &&
      summary.resultSortOfCount == 0) {
    return HookLikelyFailure.resultQualityProblem;
  }

  if (summary.checkInsCreated == 0 && summary.questionRatedTotal < 2) {
    return HookLikelyFailure.notEnoughData;
  }

  return HookLikelyFailure.notEnoughData;
}

double? computeClarityIssueRate({
  required int checkInsDueShown,
  required int confusingCount,
  required int examplesOpenedCount,
  required Map<String, int> notUsefulReasonCounts,
}) {
  if (checkInsDueShown == 0) return null;
  final vague = notUsefulReasonCounts[HookDiagnosisNotUsefulReason.tooVague] ?? 0;
  final confusingReason =
      notUsefulReasonCounts[HookDiagnosisNotUsefulReason.confusing] ?? 0;
  final signals = confusingCount + examplesOpenedCount + vague + confusingReason;
  return (signals / checkInsDueShown).clamp(0.0, 1.0);
}

HookDiagnosisSummary buildHookDiagnosisSummary({
  required List<HookDiagnosisEvent> events,
  required int checkInsCreated,
  required int checkInsDueShown,
  required int checkInsCompleted,
  int examplesOpenedCount = 0,
  int checkInClarityCardShownCount = 0,
  int checkInMomentRecordedCount = 0,
}) {
  var questionUseful = 0;
  var questionSortOf = 0;
  var questionNotUseful = 0;
  var resultUseful = 0;
  var resultSortOf = 0;
  var resultNotUseful = 0;
  var confusing = 0;
  var forgot = 0;
  var didNotCare = 0;
  final reasonCounts = <String, int>{};
  final notUsefulReasonCounts = <String, int>{};

  for (final e in events) {
    switch (e.type) {
      case HookDiagnosisEventType.checkInQuestionRated:
        switch (e.rating) {
          case HookDiagnosisRating.yes:
            questionUseful++;
          case HookDiagnosisRating.sortOf:
            questionSortOf++;
          case HookDiagnosisRating.notReally:
            questionNotUseful++;
        }
      case HookDiagnosisEventType.checkInResultRated:
        switch (e.rating) {
          case HookDiagnosisRating.yes:
            resultUseful++;
          case HookDiagnosisRating.sortOf:
            resultSortOf++;
          case HookDiagnosisRating.notReally:
            resultNotUseful++;
        }
      case HookDiagnosisEventType.checkInMissedReason:
        final reason = e.reason ?? HookDiagnosisMissedReason.other;
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        if (reason == HookDiagnosisMissedReason.forgot) forgot++;
        if (reason == HookDiagnosisMissedReason.didNotCare) didNotCare++;
        if (reason == HookDiagnosisMissedReason.confusing) confusing++;
      case HookDiagnosisEventType.checkInConfusing:
        confusing++;
      case HookDiagnosisEventType.checkInResultNotUsefulReason:
        final reason = e.reason ?? HookDiagnosisNotUsefulReason.tooVague;
        notUsefulReasonCounts[reason] =
            (notUsefulReasonCounts[reason] ?? 0) + 1;
        if (reason == HookDiagnosisNotUsefulReason.confusing) confusing++;
    }
  }

  final completionRate = checkInsCreated == 0
      ? 0.0
      : checkInsCompleted / checkInsCreated;

  final base = HookDiagnosisSummary(
    checkInsCreated: checkInsCreated,
    checkInsDueShown: checkInsDueShown,
    checkInsCompleted: checkInsCompleted,
    checkInCompletionRate: completionRate,
    checkInQuestionRatedUseful: questionUseful,
    checkInQuestionRatedSortOf: questionSortOf,
    checkInQuestionRatedNotUseful: questionNotUseful,
    didNotReturnReasonCounts: reasonCounts,
    confusingCount: confusing,
    forgotCount: forgot,
    didNotCareCount: didNotCare,
    resultUsefulCount: resultUseful,
    resultNotUsefulCount: resultNotUseful,
    resultSortOfCount: resultSortOf,
    likelyFailure: HookLikelyFailure.notEnoughData,
    examplesOpenedCount: examplesOpenedCount,
    checkInClarityCardShownCount: checkInClarityCardShownCount,
    checkInMomentRecordedCount: checkInMomentRecordedCount,
    notUsefulReasonCounts: notUsefulReasonCounts,
    clarityIssueRate: computeClarityIssueRate(
      checkInsDueShown: checkInsDueShown,
      confusingCount: confusing,
      examplesOpenedCount: examplesOpenedCount,
      notUsefulReasonCounts: notUsefulReasonCounts,
    ),
  );

  return HookDiagnosisSummary(
    checkInsCreated: base.checkInsCreated,
    checkInsDueShown: base.checkInsDueShown,
    checkInsCompleted: base.checkInsCompleted,
    checkInCompletionRate: base.checkInCompletionRate,
    checkInQuestionRatedUseful: base.checkInQuestionRatedUseful,
    checkInQuestionRatedSortOf: base.checkInQuestionRatedSortOf,
    checkInQuestionRatedNotUseful: base.checkInQuestionRatedNotUseful,
    didNotReturnReasonCounts: base.didNotReturnReasonCounts,
    confusingCount: base.confusingCount,
    forgotCount: base.forgotCount,
    didNotCareCount: base.didNotCareCount,
    resultUsefulCount: base.resultUsefulCount,
    resultNotUsefulCount: base.resultNotUsefulCount,
    resultSortOfCount: base.resultSortOfCount,
    likelyFailure: computeLikelyFailure(base),
    examplesOpenedCount: base.examplesOpenedCount,
    checkInClarityCardShownCount: base.checkInClarityCardShownCount,
    checkInMomentRecordedCount: base.checkInMomentRecordedCount,
    notUsefulReasonCounts: base.notUsefulReasonCounts,
    clarityIssueRate: base.clarityIssueRate,
  );
}
