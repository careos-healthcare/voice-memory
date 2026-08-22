import 'package:archiveme_mobile/features/import/import_record.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Converts [ExternalImportRecord] rows into persisted [JournalEntry] objects.
abstract final class JournalEntryImporter {
  JournalEntryImporter._();

  static JournalEntry toJournalEntry(ExternalImportRecord record) {
    final createdAt = record.createdAt ?? DateTime.now().toUtc();
    final text = record.text.trim();
    return JournalEntry(
      id: JournalSyncIds.newOfflineEntryId(),
      createdAt: createdAt,
      transcript: text,
      durationSeconds: 0,
      reflection: Reflection(
        mood: 'imported',
        emotionalIntensity: 5,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: text.length > 120 ? text.substring(0, 120) : text,
        repeatedSignal: '',
      ),
      captureSource: 'import',
    );
  }

  static Future<JournalImportResult> persistAll({
    required JournalStore store,
    required List<ExternalImportRecord> records,
    bool skipDuplicates = true,
  }) async {
    if (records.isEmpty) {
      return const JournalImportResult(imported: 0, skipped: 0);
    }

    final existing = await store.loadAll();
    final existingTexts = skipDuplicates
        ? existing
            .map((e) => '${e.createdAt.toIso8601String()}|${e.transcript.trim()}')
            .toSet()
        : <String>{};

    var imported = 0;
    var skipped = 0;
    for (final record in records) {
      final entry = toJournalEntry(record);
      final key = '${entry.createdAt.toIso8601String()}|${entry.transcript.trim()}';
      if (skipDuplicates && existingTexts.contains(key)) {
        skipped += 1;
        continue;
      }
      await store.save(entry, first25Source: 'external_import');
      existingTexts.add(key);
      imported += 1;
    }

    return JournalImportResult(imported: imported, skipped: skipped);
  }
}

class JournalImportResult {
  const JournalImportResult({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}