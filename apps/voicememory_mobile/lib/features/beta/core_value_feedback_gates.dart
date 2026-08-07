import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import 'archive_beta_mission_gate.dart';
import 'core_value_feedback_model.dart';
import 'core_value_feedback_store.dart';

/// Visibility rules for the core value beta feedback prompt.
abstract final class CoreValueFeedbackGates {
  CoreValueFeedbackGates._();

  static bool hasFirstProof({
    required int entryCount,
    required bool hasConfirmedRepeatFoundation,
  }) => entryCount >= 3 && hasConfirmedRepeatFoundation;

  static bool shouldShow({
    required CoreValueFeedbackSource source,
    required int entryCount,
    required bool hasConfirmedRepeatFoundation,
    required bool isRecording,
    required bool isDegraded,
    required bool isProPaywallVisible,
    required bool placementEligible,
    CoreValueFeedbackRecord? record,
    bool? dismissed,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (dismissed ?? CoreValueFeedbackStore.isDismissed) return false;
    if (isRecording) return false;
    if (isDegraded) return false;
    if (isProPaywallVisible) return false;
    if (entryCount <= 2) return false;
    if (!hasConfirmedRepeatFoundation) return false;
    if (!hasFirstProof(
      entryCount: entryCount,
      hasConfirmedRepeatFoundation: hasConfirmedRepeatFoundation,
    )) {
      return false;
    }

    final resolved = record ?? CoreValueFeedbackStore.cached;
    if (resolved.answered) return false;
    return placementEligible;
  }

  static bool shouldShowOnRecordPostFirstProof({
    required bool showFirstProofMoment,
    required bool isPostSaveDone,
    required int entryCount,
    required bool hasConfirmedRepeatFoundation,
    required bool isRecording,
    required bool isDegradedPostSave,
    required bool isProPaywallVisible,
    CoreValueFeedbackRecord? record,
    bool? dismissed,
  }) => shouldShow(
    source: CoreValueFeedbackSource.recordPostFirstProof,
    entryCount: entryCount,
    hasConfirmedRepeatFoundation: hasConfirmedRepeatFoundation,
    isRecording: isRecording,
    isDegraded: isDegradedPostSave,
    isProPaywallVisible: isProPaywallVisible,
    placementEligible: showFirstProofMoment && isPostSaveDone,
    record: record,
    dismissed: dismissed,
  );

  static bool shouldShowOnPatternsArchive({
    required bool showArchiveCurrentBelief,
    required bool archiveBeliefSurfaceVisible,
    required int entryCount,
    required List<JournalEntry> entries,
    required bool isRecording,
    required bool isProPaywallVisible,
    CoreValueFeedbackRecord? record,
    bool? dismissed,
  }) => shouldShow(
    source: CoreValueFeedbackSource.patternsArchive,
    entryCount: entryCount,
    hasConfirmedRepeatFoundation:
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
    isRecording: isRecording,
    isDegraded: false,
    isProPaywallVisible: isProPaywallVisible,
    placementEligible: showArchiveCurrentBelief && archiveBeliefSurfaceVisible,
    record: record,
    dismissed: dismissed,
  );
}
