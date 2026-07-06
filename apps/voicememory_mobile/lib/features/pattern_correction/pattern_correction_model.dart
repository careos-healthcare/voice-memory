import 'package:flutter/foundation.dart';

/// Why a pattern surface feels wrong — safe ids for analytics only.
enum PatternCorrectionReason {
  wrongPattern,
  wrongWording,
  tooPersonal,
  doesNotBelong,
  notUseful,
}

/// Corrective actions routed to existing archive flows.
enum PatternCorrectionAction {
  renamePattern,
  removeFromPattern,
  correctTranscript,
  deleteMoment,
  privacyCentre,
  betaFeedback,
  keepRecording,
}

/// Inputs for routing pattern correction without transcript or pattern text.
class PatternCorrectionContext {
  const PatternCorrectionContext({
    required this.source,
    required this.entryCount,
    this.patternKey,
    this.patternLabel,
    this.latestEntryId,
    required this.canRenamePattern,
    required this.canCorrectTranscript,
    required this.canRemoveFromPattern,
    required this.canDeleteMoment,
    this.onMomentChanged,
    this.onKeepRecording,
  });

  final String source;
  final int entryCount;
  final String? patternKey;
  final String? patternLabel;
  final String? latestEntryId;
  final bool canRenamePattern;
  final bool canCorrectTranscript;
  final bool canRemoveFromPattern;
  final bool canDeleteMoment;
  final Future<void> Function()? onMomentChanged;
  final VoidCallback? onKeepRecording;

  bool allows(PatternCorrectionAction action) => switch (action) {
        PatternCorrectionAction.renamePattern =>
          canRenamePattern && (patternLabel?.trim().isNotEmpty ?? false),
        PatternCorrectionAction.removeFromPattern =>
          canRemoveFromPattern &&
              (patternKey?.isNotEmpty ?? false) &&
              (latestEntryId?.isNotEmpty ?? false),
        PatternCorrectionAction.correctTranscript =>
          canCorrectTranscript && (latestEntryId?.isNotEmpty ?? false),
        PatternCorrectionAction.deleteMoment =>
          canDeleteMoment && (latestEntryId?.isNotEmpty ?? false),
        PatternCorrectionAction.privacyCentre => true,
        PatternCorrectionAction.betaFeedback => true,
        PatternCorrectionAction.keepRecording => onKeepRecording != null,
      };
}
