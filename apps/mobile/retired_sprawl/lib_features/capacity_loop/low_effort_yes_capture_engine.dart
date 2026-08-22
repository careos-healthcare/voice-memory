import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_pull_reason_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/yes_capture_timing.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Builds low-effort yes capture visibility and saves fixed local markers.
class LowEffortYesCaptureEngine {
  const LowEffortYesCaptureEngine();

  LowEffortYesCaptureResult build(LowEffortYesCaptureInput input) {
    if (!showQuickCapture(input)) {
      return LowEffortYesCaptureResult.hidden;
    }

    return LowEffortYesCaptureResult(
      showCard: true,
      title: LowEffortYesCaptureCopy.title,
      body: LowEffortYesCaptureCopy.body,
      pullSectionTitle: LowEffortYesCaptureCopy.pullSectionTitle,
      decisionSectionTitle: LowEffortYesCaptureCopy.decisionSectionTitle,
      primaryCtaLabel: LowEffortYesCaptureCopy.quickSaveCta,
      secondaryCtaLabel: LowEffortYesCaptureCopy.recordInsteadCta,
      optionalVoiceNoteLabel: LowEffortYesCaptureCopy.optionalVoiceNoteCta,
      timingSectionTitle: LowEffortYesCaptureCopy.timingSectionTitle,
      timingIds: LowEffortYesCaptureCopy.timingIds(),
      pullReasonIds: LowEffortYesCaptureCopy.pullReasonIds(),
      decisionOutcomeIds: LowEffortYesCaptureCopy.decisionOutcomeIds(),
    );
  }

  static bool showQuickCapture(LowEffortYesCaptureInput input) =>
      input.capacityWedgeActive && !input.sampleMode && !input.screenshotMode;

  static bool isQuickCaptureEntry(JournalEntry entry) =>
      LowEffortYesCaptureIds.matchesContextTag(entry.captureContextTag);

  Future<LowEffortYesCaptureSaveResult> saveQuickCapture({
    required JournalStore journal,
    required LowEffortYesCaptureSaveRequest request,
    CapacityPullReasonStore? pullReasonStore,
    CapacityDecisionOutcomeStore? outcomeStore,
  }) async {
    final pullStore = pullReasonStore ?? CapacityPullReasonStore.instance();
    final decisionStore =
        outcomeStore ?? CapacityDecisionOutcomeStore.instance();
    final timingId = request.timingId.trim();
    if (!YesCaptureTimingIds.all.contains(timingId)) {
      throw ArgumentError.value(timingId, 'timingId', 'unsupported timing id');
    }
    final entryId = _newEntryId();
    final entry = JournalEntry(
      id: entryId,
      createdAt: DateTime.now().toUtc(),
      transcript: '',
      durationSeconds: 0,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: LowEffortYesCaptureCopy.entryObservation,
        repeatedSignal: '',
      ),
      captureContextTag: LowEffortYesCaptureIds.contextTagForTiming(timingId),
    );

    await journal.save(entry, first25Source: LowEffortYesCaptureIds.saveSource);
    await pullStore.saveAnswered(
      sourceEntryId: entryId,
      reasonIds: [request.pullReasonId],
    );

    var savedOutcome = false;
    final outcomeId = request.outcomeId?.trim();
    if (outcomeId != null && outcomeId.isNotEmpty) {
      await decisionStore.saveAnswered(
        sourceEntryId: entryId,
        outcomeId: outcomeId,
      );
      savedOutcome = true;
    }

    return LowEffortYesCaptureSaveResult(
      entryId: entryId,
      savedPullReason: true,
      savedOutcome: savedOutcome,
    );
  }

  static String _newEntryId() =>
      'quick_yes_${DateTime.now().toUtc().millisecondsSinceEpoch}';
}