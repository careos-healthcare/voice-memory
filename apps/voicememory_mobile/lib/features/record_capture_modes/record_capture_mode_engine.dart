import '../../models/journal_entry.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import 'record_capture_mode_copy.dart';
import 'record_capture_mode_model.dart';

/// When capture modes appear and how quiet-day saves are classified.
abstract final class RecordCaptureModeEngine {
  RecordCaptureModeEngine._();

  static const _quietDayPhrases = {
    'nothing much today',
    'nothing much today.',
    'quiet day',
    'quiet day.',
    'not much today',
    'not much today.',
  };

  /// Near Type instead on Record ready — capture-first, not post-save.
  static bool shouldShow({
    required bool loaded,
    required bool isReady,
    required bool isPostSave,
  }) =>
      loaded && isReady && !isPostSave;

  static RecordCaptureMode? modeById(RecordCaptureModeId id) {
    for (final mode in RecordCaptureMode.all) {
      if (mode.id == id) return mode;
    }
    return null;
  }

  static bool isQuietDayText(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _quietDayPhrases.contains(normalized);
  }

  static bool entryIsQuietDay(JournalEntry entry) =>
      isQuietDayText(ComparableEvidenceText.userText(entry));

  static String quietDaySaveText() => RecordCaptureModeCopy.quietDayDefaultSaveText;
}
