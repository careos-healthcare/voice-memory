import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_store.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/services/app_services.dart';

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

    // The user authored this replacement themselves — there is no AI rewrite
    // in this path — so the corrected text stays quotable.
    final updated = applyFinalTranscriptToVoiceEntry(
      existing,
      finalTranscript: trimmed,
      provenance: TranscriptProvenance.userEdited,
    );

    await AppServices.instance.journalStore.update(updated);

    if (AppServices.isInitialized) {
      try {
        await PressureCheckInStore.instance().syncFromJournalEntry(updated);
      } catch (e, stackTrace) {
        AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
        }
    }

    return updated;
  }
}