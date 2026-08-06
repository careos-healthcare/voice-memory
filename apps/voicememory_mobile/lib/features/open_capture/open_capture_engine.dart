import '../../models/journal_entry.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'open_capture_model.dart';

/// Visibility and prompt helpers for open capture chips — no proof changes.
abstract final class OpenCaptureEngine {
  OpenCaptureEngine._();

  static const maxEarlyEntryCount = 7;

  static bool shouldShow({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool isPermissionBlocked,
    required int entryCount,
  }) {
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (isPermissionBlocked) return false;
    if (entryCount > maxEarlyEntryCount) return false;
    return true;
  }

  static OpenCaptureChip? chipByType(OpenCaptureChipType type) {
    for (final chip in OpenCaptureChip.all) {
      if (chip.type == type) return chip;
    }
    return null;
  }

  static String? promptStarterFor(OpenCaptureChipType type) =>
      chipByType(type)?.promptStarter;

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}
