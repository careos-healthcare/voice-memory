import '../../models/journal_entry.dart';
import 'first25_recording_retention.dart';
import 'first25_user_metrics.dart';

/// Journal save hook — activation + retention without coupling [JournalStore] to services.
abstract class First25JournalHooks {
  First25JournalHooks._();

  static Future<void> onJournalSave({
    required JournalEntry entry,
    required bool isNew,
    required String source,
  }) async {
    if (!isNew || !First25RecordingRetention.isEligibleRecording(entry)) return;
    await First25UserMetrics.onEligibleRecordingSaved(
      entryId: entry.id,
      createdAt: entry.createdAt,
      source: source,
    );
  }
}
