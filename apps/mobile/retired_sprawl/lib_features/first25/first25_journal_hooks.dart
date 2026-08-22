import 'package:archiveme_mobile/features/first25/first25_recording_retention.dart';
import 'package:archiveme_mobile/features/first25/first25_user_metrics.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart' show JournalStore;

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