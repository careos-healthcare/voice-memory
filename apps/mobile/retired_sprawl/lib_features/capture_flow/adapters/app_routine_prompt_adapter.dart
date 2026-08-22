import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Loads local RAG routine prompts via [AppServices.routineRagEngine].
class AppRoutinePromptAdapter implements RoutinePromptGateway {
  AppRoutinePromptAdapter({required JournalStore journalStore})
    : _journalStore = journalStore;

  final JournalStore _journalStore;

  @override
  Future<RoutineJournalPrompt?> loadPrompt({
    required JournalRoutineKind routine,
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
  }) async {
    if (!AppServices.isInitialized) return null;

    final entries = archiveEntries ?? await _journalStore.loadAll();
    final latest = latestEntry ?? _latestEntry(entries);

    final engine = await AppServices.instance.routineRagEngine;
    return switch (routine) {
      JournalRoutineKind.morning => engine.generateMorningPrompt(
        latestEntry: latest,
        archiveEntries: entries,
      ),
      JournalRoutineKind.evening => engine.generateEveningPrompt(
        latestEntry: latest,
        archiveEntries: entries,
      ),
    };
  }

  static JournalEntry? _latestEntry(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    return entries.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
  }
}
