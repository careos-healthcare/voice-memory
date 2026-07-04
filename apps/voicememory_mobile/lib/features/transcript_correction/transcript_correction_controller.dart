import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../pressure_retention/pressure_check_in_store.dart';
import '../timeline/timeline_entry_display.dart';
import 'transcript_correction_copy.dart';

class TranscriptCorrectionFailure implements Exception {
  TranscriptCorrectionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Applies a local transcript correction — no AI rewrite, same entry id/time.
abstract final class TranscriptCorrectionController {
  TranscriptCorrectionController._();

  static Future<JournalEntry> apply({
    required JournalEntry entry,
    required String correctedText,
  }) async {
    final trimmed = correctedText.trim();
    if (trimmed.isEmpty) {
      throw TranscriptCorrectionFailure(TranscriptCorrectionCopy.saveFailed);
    }

    final existing = await AppServices.instance.journalStore.getById(entry.id);
    if (existing == null) {
      throw TranscriptCorrectionFailure(TranscriptCorrectionCopy.saveFailed);
    }

    final updated = applyFinalTranscriptToVoiceEntry(
      existing,
      finalTranscript: trimmed,
    );

    await AppServices.instance.journalStore.update(updated);

    if (AppServices.isInitialized) {
      try {
        await PressureCheckInStore.instance().syncFromJournalEntry(updated);
      } catch (_) {}
    }

    return updated;
  }
}
