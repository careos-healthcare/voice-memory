import 'package:archiveme_mobile/features/coach/local_rag/coach_journal_rag_retriever.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_onnx_response_synthesizer.dart';
import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_models.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_vector_search_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Local RAG conversational coach — vector retrieval + ONNX follow-ups, offline.
class LocalCoachConversationService {
  LocalCoachConversationService({
    required CoachRagRetriever retriever,
    required CoachResponseSynthesizer synthesizer,
  }) : _retriever = retriever,
       _synthesizer = synthesizer;

  final CoachRagRetriever _retriever;
  final CoachResponseSynthesizer _synthesizer;

  static Future<LocalCoachConversationService> create({
    required JournalSqliteRepository journalRepository,
    required ReflectionEmbeddingRepository embeddingRepository,
    CoachRagRetriever? retriever,
    CoachResponseSynthesizer? synthesizer,
  }) async {
    final vectorSearch = await OfflineReflectionVectorSearchService.create(
      repository: embeddingRepository,
    );
    return LocalCoachConversationService(
      retriever: retriever ??
          CoachJournalRagRetriever(
            journalRepository: journalRepository,
            reflectionVectorSearch: vectorSearch,
          ),
      synthesizer:
          synthesizer ?? await CoachOnnxResponseSynthesizer.create(),
    );
  }

  /// Retrieves local journal context and synthesizes a coaching response.
  Future<CoachConversationResponse> respond({
    required String userQuery,
    String? liveVoicePrompt,
    List<CoachConversationTurn> conversationHistory = const [],
    List<JournalEntry>? archiveEntries,
    int maxContextChunks = 6,
    String entryId = 'coach-conversation',
  }) {
    final trimmedQuery = userQuery.trim();
    if (trimmedQuery.isEmpty) {
      throw ArgumentError.value(userQuery, 'userQuery', 'cannot be empty');
    }

    final query = CoachRagQuery(
      userQuery: trimmedQuery,
      liveVoicePrompt: liveVoicePrompt,
      maxChunks: maxContextChunks,
    );

    return OfflineReflectionSearchGuard.runOffline(() async {
      final contextChunks = await _retriever.retrieve(
        query: query,
        localEntries: archiveEntries,
      );

      return _synthesizer.synthesize(
        query: query,
        contextChunks: contextChunks,
        conversationHistory: conversationHistory,
        entryId: entryId,
      );
    });
  }
}
