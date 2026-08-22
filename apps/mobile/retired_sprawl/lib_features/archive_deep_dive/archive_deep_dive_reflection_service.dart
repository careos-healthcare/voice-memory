import 'package:archiveme_mobile/features/archive_deep_dive/archive_deep_dive_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:uuid/uuid.dart';

/// Persists deep-dive inquiry answers as on-device journal reflections.
class ArchiveDeepDiveReflectionService {
  ArchiveDeepDiveReflectionService(this._journalStore);

  final JournalStore _journalStore;
  final _uuid = const Uuid();

  static String beliefKey(String statement) =>
      statement.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<JournalEntry> saveInquiryResponse({
    required String beliefStatement,
    required ArchiveDeepDiveInquiryQuestion question,
    required String responseText,
  }) async {
    final answer = responseText.trim();
    if (answer.isEmpty) {
      throw ArgumentError('Response cannot be empty');
    }

    final entry = JournalEntry(
      id: _uuid.v4(),
      createdAt: DateTime.now().toUtc(),
      transcript: '${question.prompt}\n\n$answer',
      durationSeconds: (answer.length / 12).ceil().clamp(1, 120),
      reflection: Reflection(
        mood: 'reflective',
        emotionalIntensity: 2,
        recurringThemes: const [],
        exactLanguagePattern: answer.length > 80
            ? '${answer.substring(0, 80)}…'
            : answer,
        concreteObservation: answer,
        repeatedSignal: 'archive_deep_dive_inquiry',
      ),
      syncStatus: SyncStatus.pendingUpload,
    );
    await _journalStore.save(entry, first25Source: 'deep_dive_inquiry');
    return entry;
  }
}