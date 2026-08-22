import 'package:archiveme_mobile/features/insights/rag/local_reflection_rag_retriever.dart';
import 'package:archiveme_mobile/features/insights/rag/local_routine_prompt_generator.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_query_builder.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_vector_search_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Local RAG engine: drift retrieval + ONNX prompt generation — no cloud calls.
class LocalRoutineRagEngine {
  LocalRoutineRagEngine({
    required LocalReflectionRagRetriever retriever,
    required LocalRoutinePromptGenerator promptGenerator,
  }) : _retriever = retriever,
       _promptGenerator = promptGenerator;

  final LocalReflectionRagRetriever _retriever;
  final LocalRoutinePromptGenerator _promptGenerator;

  static Future<LocalRoutineRagEngine> create({
    required JournalSqliteRepository journalRepository,
    required ReflectionEmbeddingRepository embeddingRepository,
    LocalReflectionDataSource? reflectionModel,
  }) async {
    final vectorSearch = await OfflineReflectionVectorSearchService.create(
      repository: embeddingRepository,
    );
    final model =
        reflectionModel ?? await LocalReflectionDataSource.create();
    return LocalRoutineRagEngine(
      retriever: LocalReflectionRagRetriever(
        journalRepository: journalRepository,
        vectorSearch: vectorSearch,
      ),
      promptGenerator: LocalRoutinePromptGenerator(reflectionModel: model),
    );
  }

  Future<RoutineJournalPrompt> generateMorningPrompt({
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
    String? currentMood,
    List<String> recurringThemes = const [],
  }) {
    return _generate(
      routine: JournalRoutineKind.morning,
      latestEntry: latestEntry,
      archiveEntries: archiveEntries,
      currentMood: currentMood,
      recurringThemes: recurringThemes,
    );
  }

  Future<RoutineJournalPrompt> generateEveningPrompt({
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
    String? currentMood,
    List<String> recurringThemes = const [],
  }) {
    return _generate(
      routine: JournalRoutineKind.evening,
      latestEntry: latestEntry,
      archiveEntries: archiveEntries,
      currentMood: currentMood,
      recurringThemes: recurringThemes,
    );
  }

  Future<RoutineJournalPrompt> _generate({
    required JournalRoutineKind routine,
    JournalEntry? latestEntry,
    List<JournalEntry>? archiveEntries,
    String? currentMood,
    List<String> recurringThemes = const [],
  }) {
    return OfflineReflectionSearchGuard.runOffline(() async {
      final query = latestEntry != null
          ? RoutineRagQueryBuilder.fromLatestEntry(
              routine: routine,
              latestEntry: latestEntry,
            )
          : RoutineRagQueryBuilder.fromState(
              routine: routine,
              currentMood: currentMood,
              recurringThemes: recurringThemes,
            );

      final chunks = await _retriever.retrieve(
        query: query,
        localEntries: archiveEntries,
      );

      return _promptGenerator.generate(
        routine: routine,
        contextChunks: chunks,
        currentMood: currentMood ?? latestEntry?.reflection.mood,
        recurringThemes: recurringThemes.isNotEmpty
            ? recurringThemes
            : latestEntry?.reflection.recurringThemes ?? const [],
      );
    });
  }
}
