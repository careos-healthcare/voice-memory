import '../beta/archive_beta_mission_gate.dart';
import 'first_save_lift_copy.dart';
import 'first_save_lift_model.dart';

/// Zero-entry first save lift visibility — wins over legacy first-save cards.
abstract final class FirstSaveLiftEngine {
  FirstSaveLiftEngine._();

  static FirstSaveLiftResult build({
    required int entryCount,
    required String source,
  }) =>
      FirstSaveLiftResult(
        shouldShow: entryCount == 0,
        title: FirstSaveLiftCopy.title,
        body: FirstSaveLiftCopy.body,
        primaryCta: FirstSaveLiftCopy.primaryCta,
        secondaryCta: FirstSaveLiftCopy.secondaryCta,
        examples: [
          for (final id in FirstSaveLiftCopy.exampleOrder)
            FirstSaveLiftExample(
              id: id,
              text: FirstSaveLiftCopy.exampleTextFor(id),
            ),
        ],
        entryCount: entryCount,
        source: source,
      );

  static bool shouldShow({
    required FirstSaveLiftResult? result,
    required bool betaMissionEnabled,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool isPermissionBlocked,
    required int entryCount,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled && !betaMissionEnabled) return false;
    if (result == null || !result.shouldShow) return false;
    if (entryCount != 0) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (isPermissionBlocked) return false;
    return true;
  }
}
