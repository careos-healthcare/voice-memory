/// Fixed identifiers for low-effort yes capture — no free text.
abstract final class LowEffortYesCaptureIds {
  LowEffortYesCaptureIds._();

  static const contextTag = 'quick_yes_capture';
  static const saveSource = 'quick_yes_capture';

  static String contextTagForTiming(String timingId) => '$contextTag:$timingId';

  static bool matchesContextTag(String? tag) {
    if (tag == null || tag.isEmpty) return false;
    return tag == contextTag || tag.startsWith('$contextTag:');
  }
}

/// Engine input — local flags only.
class LowEffortYesCaptureInput {
  const LowEffortYesCaptureInput({
    required this.capacityWedgeActive,
    required this.sampleMode,
    required this.screenshotMode,
  });

  final bool capacityWedgeActive;
  final bool sampleMode;
  final bool screenshotMode;
}

/// Card / screen visibility result.
class LowEffortYesCaptureResult {
  const LowEffortYesCaptureResult({
    required this.showCard,
    required this.title,
    required this.body,
    required this.pullSectionTitle,
    required this.decisionSectionTitle,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.optionalVoiceNoteLabel,
    required this.timingSectionTitle,
    required this.timingIds,
    required this.pullReasonIds,
    required this.decisionOutcomeIds,
  });

  static const hidden = LowEffortYesCaptureResult(
    showCard: false,
    title: '',
    body: '',
    pullSectionTitle: '',
    decisionSectionTitle: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    optionalVoiceNoteLabel: '',
    timingSectionTitle: '',
    timingIds: [],
    pullReasonIds: [],
    decisionOutcomeIds: [],
  );

  final bool showCard;
  final String title;
  final String body;
  final String pullSectionTitle;
  final String decisionSectionTitle;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String optionalVoiceNoteLabel;
  final String timingSectionTitle;
  final List<String> timingIds;
  final List<String> pullReasonIds;
  final List<String> decisionOutcomeIds;
}

/// Save request — fixed ids only.
class LowEffortYesCaptureSaveRequest {
  const LowEffortYesCaptureSaveRequest({
    required this.pullReasonId,
    required this.timingId,
    this.outcomeId,
  });

  final String pullReasonId;
  final String timingId;
  final String? outcomeId;
}

class LowEffortYesCaptureSaveResult {
  const LowEffortYesCaptureSaveResult({
    required this.entryId,
    required this.savedPullReason,
    required this.savedOutcome,
  });

  final String entryId;
  final bool savedPullReason;
  final bool savedOutcome;
}
