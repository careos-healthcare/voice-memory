/// Steps a returning user moves through when answering yesterday's check:
/// open app -> see question -> tap answer -> record one short moment -> done.
enum ReturnDayFrictionStage {
  notDue,
  dueShown,
  answerSelected,
  recordingStarted,
  momentSaved,
  loopClosed,
}

extension ReturnDayFrictionStageIds on ReturnDayFrictionStage {
  String get id => name;
}

ReturnDayFrictionStage returnDayFrictionStageFromId(String? raw) {
  for (final s in ReturnDayFrictionStage.values) {
    if (s.id == raw) return s;
  }
  return ReturnDayFrictionStage.notDue;
}

/// Where a returning user stopped, used to spot the weak point on return day.
enum ReturnDayDropoffPoint {
  answerFriction,
  recordingFriction,
  saveFriction,
  none,
}

extension ReturnDayDropoffPointIds on ReturnDayDropoffPoint {
  String get id => name;
}

/// Tracks how fast a returning user answers and closes the loop so the
/// return-day flow can stay short and the team can see where users stall.
class ReturnDayFrictionState {
  const ReturnDayFrictionState({
    this.checkInId,
    this.stage = ReturnDayFrictionStage.notDue,
    this.dueShownAt,
    this.answerSelectedAt,
    this.recordingStartedAt,
    this.momentSavedAt,
    this.loopClosedAt,
    this.selectedAnswer,
  });

  final String? checkInId;
  final ReturnDayFrictionStage stage;
  final DateTime? dueShownAt;
  final DateTime? answerSelectedAt;
  final DateTime? recordingStartedAt;
  final DateTime? momentSavedAt;
  final DateTime? loopClosedAt;
  final String? selectedAnswer;

  static const empty = ReturnDayFrictionState();

  bool get isComplete => stage == ReturnDayFrictionStage.loopClosed;

  /// Whether the user has chosen one of the four answers yet.
  bool get hasAnswered =>
      stage.index >= ReturnDayFrictionStage.answerSelected.index;

  int? get secondsToAnswer {
    final start = dueShownAt;
    final answered = answerSelectedAt;
    if (start == null || answered == null) return null;
    final diff = answered.difference(start).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  int? get secondsToLoopClosed {
    final start = dueShownAt;
    final closed = loopClosedAt;
    if (start == null || closed == null) return null;
    final diff = closed.difference(start).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  ReturnDayDropoffPoint get dropoffPoint {
    switch (stage) {
      case ReturnDayFrictionStage.dueShown:
        return ReturnDayDropoffPoint.answerFriction;
      case ReturnDayFrictionStage.answerSelected:
        return ReturnDayDropoffPoint.recordingFriction;
      case ReturnDayFrictionStage.recordingStarted:
        return ReturnDayDropoffPoint.saveFriction;
      case ReturnDayFrictionStage.notDue:
      case ReturnDayFrictionStage.momentSaved:
      case ReturnDayFrictionStage.loopClosed:
        return ReturnDayDropoffPoint.none;
    }
  }

  ReturnDayFrictionState copyWith({
    String? checkInId,
    ReturnDayFrictionStage? stage,
    DateTime? dueShownAt,
    DateTime? answerSelectedAt,
    DateTime? recordingStartedAt,
    DateTime? momentSavedAt,
    DateTime? loopClosedAt,
    String? selectedAnswer,
  }) {
    return ReturnDayFrictionState(
      checkInId: checkInId ?? this.checkInId,
      stage: stage ?? this.stage,
      dueShownAt: dueShownAt ?? this.dueShownAt,
      answerSelectedAt: answerSelectedAt ?? this.answerSelectedAt,
      recordingStartedAt: recordingStartedAt ?? this.recordingStartedAt,
      momentSavedAt: momentSavedAt ?? this.momentSavedAt,
      loopClosedAt: loopClosedAt ?? this.loopClosedAt,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
    );
  }

  Map<String, dynamic> toJson() => {
    if (checkInId != null) 'checkInId': checkInId,
    'stage': stage.id,
    if (dueShownAt != null) 'dueShownAt': dueShownAt!.toUtc().toIso8601String(),
    if (answerSelectedAt != null)
      'answerSelectedAt': answerSelectedAt!.toUtc().toIso8601String(),
    if (recordingStartedAt != null)
      'recordingStartedAt': recordingStartedAt!.toUtc().toIso8601String(),
    if (momentSavedAt != null)
      'momentSavedAt': momentSavedAt!.toUtc().toIso8601String(),
    if (loopClosedAt != null)
      'loopClosedAt': loopClosedAt!.toUtc().toIso8601String(),
    if (selectedAnswer != null) 'selectedAnswer': selectedAnswer,
  };

  static ReturnDayFrictionState fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return empty;
    DateTime? parse(String key) => DateTime.tryParse(map[key] as String? ?? '');
    return ReturnDayFrictionState(
      checkInId: map['checkInId'] as String?,
      stage: returnDayFrictionStageFromId(map['stage'] as String?),
      dueShownAt: parse('dueShownAt'),
      answerSelectedAt: parse('answerSelectedAt'),
      recordingStartedAt: parse('recordingStartedAt'),
      momentSavedAt: parse('momentSavedAt'),
      loopClosedAt: parse('loopClosedAt'),
      selectedAnswer: map['selectedAnswer'] as String?,
    );
  }
}