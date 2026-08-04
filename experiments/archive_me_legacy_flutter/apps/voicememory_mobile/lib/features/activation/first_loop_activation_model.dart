/// Steps a brand-new user moves through in their very first sitting:
/// record one moment -> see first pattern -> choose tomorrow's check.
enum FirstLoopActivationStage {
  notStarted,
  openedRecord,
  recordingStarted,
  firstMomentSaved,
  firstPatternShown,
  tomorrowCheckChosen,
  loopReady,
}

extension FirstLoopActivationStageIds on FirstLoopActivationStage {
  String get id => name;
}

FirstLoopActivationStage firstLoopActivationStageFromId(String? raw) {
  for (final s in FirstLoopActivationStage.values) {
    if (s.id == raw) return s;
  }
  return FirstLoopActivationStage.notStarted;
}

/// Where a user stopped, used to spot the first weak point in onboarding.
enum FirstLoopDropoffPoint {
  recordFriction,
  saveFriction,
  patternIssue,
  questionIssue,
  none,
}

extension FirstLoopDropoffPointIds on FirstLoopDropoffPoint {
  String get id => name;
}

/// Tracks progress through the compressed first loop so the first session can
/// stay simple and the team can see where new users stall.
class FirstLoopActivationState {
  const FirstLoopActivationState({
    this.stage = FirstLoopActivationStage.notStarted,
    this.openedAt,
    this.firstRecordingStartedAt,
    this.firstMomentSavedAt,
    this.firstPatternShownAt,
    this.tomorrowCheckChosenAt,
    this.completedAt,
    this.firstPatternTitle,
    this.tomorrowQuestion,
  });

  final FirstLoopActivationStage stage;
  final DateTime? openedAt;
  final DateTime? firstRecordingStartedAt;
  final DateTime? firstMomentSavedAt;
  final DateTime? firstPatternShownAt;
  final DateTime? tomorrowCheckChosenAt;
  final DateTime? completedAt;
  final String? firstPatternTitle;
  final String? tomorrowQuestion;

  static const empty = FirstLoopActivationState();

  bool get isComplete => stage == FirstLoopActivationStage.loopReady;

  /// Whether the user has saved their first moment yet.
  bool get hasFirstMoment =>
      stage.index >= FirstLoopActivationStage.firstMomentSaved.index;

  int? get secondsToFirstSave {
    final start = openedAt;
    final saved = firstMomentSavedAt;
    if (start == null || saved == null) return null;
    final diff = saved.difference(start).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  int? get secondsToLoopReady {
    final start = openedAt;
    final done = completedAt;
    if (start == null || done == null) return null;
    final diff = done.difference(start).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  FirstLoopDropoffPoint get dropoffPoint {
    switch (stage) {
      case FirstLoopActivationStage.openedRecord:
        return FirstLoopDropoffPoint.recordFriction;
      case FirstLoopActivationStage.recordingStarted:
        return FirstLoopDropoffPoint.saveFriction;
      case FirstLoopActivationStage.firstMomentSaved:
        return FirstLoopDropoffPoint.patternIssue;
      case FirstLoopActivationStage.firstPatternShown:
        return FirstLoopDropoffPoint.questionIssue;
      case FirstLoopActivationStage.notStarted:
      case FirstLoopActivationStage.tomorrowCheckChosen:
      case FirstLoopActivationStage.loopReady:
        return FirstLoopDropoffPoint.none;
    }
  }

  FirstLoopActivationState copyWith({
    FirstLoopActivationStage? stage,
    DateTime? openedAt,
    DateTime? firstRecordingStartedAt,
    DateTime? firstMomentSavedAt,
    DateTime? firstPatternShownAt,
    DateTime? tomorrowCheckChosenAt,
    DateTime? completedAt,
    String? firstPatternTitle,
    String? tomorrowQuestion,
  }) {
    return FirstLoopActivationState(
      stage: stage ?? this.stage,
      openedAt: openedAt ?? this.openedAt,
      firstRecordingStartedAt:
          firstRecordingStartedAt ?? this.firstRecordingStartedAt,
      firstMomentSavedAt: firstMomentSavedAt ?? this.firstMomentSavedAt,
      firstPatternShownAt: firstPatternShownAt ?? this.firstPatternShownAt,
      tomorrowCheckChosenAt:
          tomorrowCheckChosenAt ?? this.tomorrowCheckChosenAt,
      completedAt: completedAt ?? this.completedAt,
      firstPatternTitle: firstPatternTitle ?? this.firstPatternTitle,
      tomorrowQuestion: tomorrowQuestion ?? this.tomorrowQuestion,
    );
  }

  Map<String, dynamic> toJson() => {
    'stage': stage.id,
    if (openedAt != null) 'openedAt': openedAt!.toUtc().toIso8601String(),
    if (firstRecordingStartedAt != null)
      'firstRecordingStartedAt': firstRecordingStartedAt!
          .toUtc()
          .toIso8601String(),
    if (firstMomentSavedAt != null)
      'firstMomentSavedAt': firstMomentSavedAt!.toUtc().toIso8601String(),
    if (firstPatternShownAt != null)
      'firstPatternShownAt': firstPatternShownAt!.toUtc().toIso8601String(),
    if (tomorrowCheckChosenAt != null)
      'tomorrowCheckChosenAt': tomorrowCheckChosenAt!.toUtc().toIso8601String(),
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (firstPatternTitle != null) 'firstPatternTitle': firstPatternTitle,
    if (tomorrowQuestion != null) 'tomorrowQuestion': tomorrowQuestion,
  };

  static FirstLoopActivationState fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return empty;
    DateTime? parse(String key) => DateTime.tryParse(map[key] as String? ?? '');
    return FirstLoopActivationState(
      stage: firstLoopActivationStageFromId(map['stage'] as String?),
      openedAt: parse('openedAt'),
      firstRecordingStartedAt: parse('firstRecordingStartedAt'),
      firstMomentSavedAt: parse('firstMomentSavedAt'),
      firstPatternShownAt: parse('firstPatternShownAt'),
      tomorrowCheckChosenAt: parse('tomorrowCheckChosenAt'),
      completedAt: parse('completedAt'),
      firstPatternTitle: map['firstPatternTitle'] as String?,
      tomorrowQuestion: map['tomorrowQuestion'] as String?,
    );
  }
}
