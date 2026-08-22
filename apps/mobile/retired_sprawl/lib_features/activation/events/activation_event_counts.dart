/// v1 local activation counters — generic map with typed accessors for trial QA.
class ActivationEventCounts {
  const ActivationEventCounts({
    this.participantId,
    this.counters = const {},
    this.latestProValuePreviewType,
    this.latestMemoryQualityLevel,
    this.latestCurrentObjectiveType,
  });

  factory ActivationEventCounts.fromMap(Map<String, dynamic> map) {
    final counters = <String, int>{};
    String? participantId;
    String? latestProValuePreviewType;
    String? latestMemoryQualityLevel;
    String? latestCurrentObjectiveType;
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'participantId' && value is String) {
        participantId = value;
        continue;
      }
      if (key == 'latestProValuePreviewType' && value is String) {
        latestProValuePreviewType = value;
        continue;
      }
      if (key == 'latestMemoryQualityLevel' && value is String) {
        latestMemoryQualityLevel = value;
        continue;
      }
      if (key == 'latestCurrentObjectiveType' && value is String) {
        latestCurrentObjectiveType = value;
        continue;
      }
      if (value is num) {
        counters[key] = value.toInt();
      }
    }
    return ActivationEventCounts(
      participantId: participantId,
      counters: counters,
      latestProValuePreviewType: latestProValuePreviewType,
      latestMemoryQualityLevel: latestMemoryQualityLevel,
      latestCurrentObjectiveType: latestCurrentObjectiveType,
    );
  }

  final String? participantId;
  final Map<String, int> counters;
  final String? latestProValuePreviewType;
  final String? latestMemoryQualityLevel;
  final String? latestCurrentObjectiveType;

  int count(String field) => counters[field] ?? 0;

  int get firstReflectionSaved => count('firstReflectionSaved');
  int get secondReflectionSaved => count('secondReflectionSaved');
  int get thirdReflectionSaved => count('thirdReflectionSaved');
  int get firstPatternShown => count('firstPatternShown');
  int get firstPatternAccepted =>
      count('firstPatternAccepted') > 0
          ? count('firstPatternAccepted')
          : watchForPromptAccepted;
  int get firstPatternCorrected => count('first_pattern_corrected');
  int get watchForPromptShown => count('watch_for_prompt_shown');
  int get watchForPromptAccepted => count('watch_for_prompt_accepted');
  int get returnedNextDay => count('returnedNextDay');
  int get usefulnessYes => count('usefulnessYes');
  int get usefulnessSortOf => count('usefulnessSortOf');
  int get usefulnessNotReally => count('usefulnessNotReally');
  int get trialAppOpened => count('trialAppOpened');
  int get trialRecordCtaTapped => count('trialRecordCtaTapped');
  int get trialMicPermissionRequested => count('trialMicPermissionRequested');
  int get trialMicPermissionDenied => count('trialMicPermissionDenied');
  int get trialRecordingStarted => count('trialRecordingStarted');
  int get trialRecordingCancelled => count('trialRecordingCancelled');
  int get trialSaveStarted => count('trialSaveStarted');
  int get trialSaveCompleted => count('trialSaveCompleted');
  int get trialClosedBeforeWatchForAccepted =>
      count('trialClosedBeforeWatchForAccepted');
  int get trialExportCopied => count('trialExportCopied');
  int get activationFirstRecordCardShown =>
      count('activationFirstRecordCardShown');
  int get activationFirstRecordCtaTapped =>
      count('activationFirstRecordCtaTapped');
  int get activationStarterPromptSelected =>
      count('activationStarterPromptSelected');
  int get activationFirstSaveCompleted => count('activationFirstSaveCompleted');
  int get paywallShown => count('paywallShown');
  int get paywallContinueTapped => count('paywallContinueTapped');
  int get paywallDismissed => count('paywallDismissed');
  int get restoreTapped => count('restoreTapped');
  int get proValuePreviewShown => count('proValuePreviewShown');
  int get proValuePreviewUnlockTapped => count('proValuePreviewUnlockTapped');
  int get proValuePreviewDismissed => count('proValuePreviewDismissed');
  int get annualPlanShown => count('annualPlanShown');
  int get monthlyPlanShown => count('monthlyPlanShown');
  int get annualPlanSelected => count('annualPlanSelected');
  int get monthlyPlanSelected => count('monthlyPlanSelected');

  ActivationEventCounts copyWith({
    String? participantId,
    Map<String, int>? counters,
    String? latestProValuePreviewType,
    String? latestMemoryQualityLevel,
    String? latestCurrentObjectiveType,
  }) {
    return ActivationEventCounts(
      participantId: participantId ?? this.participantId,
      counters: counters ?? this.counters,
      latestProValuePreviewType:
          latestProValuePreviewType ?? this.latestProValuePreviewType,
      latestMemoryQualityLevel:
          latestMemoryQualityLevel ?? this.latestMemoryQualityLevel,
      latestCurrentObjectiveType:
          latestCurrentObjectiveType ?? this.latestCurrentObjectiveType,
    );
  }

  ActivationEventCounts incrementField(String field) {
    final next = Map<String, int>.from(counters);
    next[field] = (next[field] ?? 0) + 1;
    return copyWith(counters: next);
  }

  Map<String, dynamic> toMap() {
    return {
      if (participantId != null) 'participantId': participantId,
      if (latestProValuePreviewType != null)
        'latestProValuePreviewType': latestProValuePreviewType,
      if (latestMemoryQualityLevel != null)
        'latestMemoryQualityLevel': latestMemoryQualityLevel,
      if (latestCurrentObjectiveType != null)
        'latestCurrentObjectiveType': latestCurrentObjectiveType,
      ...counters.map(MapEntry.new),
    };
  }
}