import 'package:uuid/uuid.dart';

import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../features/sync/encrypted_sync_engine.dart';
import '../../models/journal_entry.dart';
import '../../models/reflection.dart';
import '../../storage/journal_store.dart';
import '../../services/ai/hybrid_ai_router.dart';

class ConversationIngestionResult {
  const ConversationIngestionResult({
    required this.entry,
    required this.graph,
    required this.summary,
    required this.e2eeQueued,
  });

  final JournalEntry entry;
  final PersonalKnowledgeGraph graph;
  final String summary;
  final bool e2eeQueued;
}

class ConversationIngestionTask {
  const ConversationIngestionTask({
    required this.journalStore,
    required this.graphStore,
    required this.hybridAiRouter,
    this.syncEngine,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final JournalStore journalStore;
  final PersonalKnowledgeGraphStore graphStore;
  final HybridAiRouter hybridAiRouter;
  final EncryptedSyncEngine? syncEngine;
  final DateTime Function() _clock;

  Future<ConversationIngestionResult?> run({
    required List<VoiceConversationTranscriptLine> transcript,
    required Duration duration,
    String? entryId,
  }) async {
    final userLines = transcript
        .where((line) => line.role == VoiceConversationRole.user)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (userLines.isEmpty) return null;
    final fullTranscript = transcript
        .where((line) => line.text.trim().isNotEmpty)
        .map(
          (line) =>
              '${line.role == VoiceConversationRole.user ? 'You' : 'ArchiveMe'}: ${line.text.trim()}',
        )
        .join('\n');
    final summary = _summarize(userLines);
    final entry = JournalEntry(
      id: entryId ?? const Uuid().v4(),
      createdAt: _clock().toUtc(),
      transcript: fullTranscript,
      durationSeconds: duration.inSeconds,
      captureContextTag: 'memory_graph_voice_conversation',
      reflection: Reflection(
        mood: 'reflective',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: userLines.first,
        concreteObservation: summary,
        repeatedSignal: '',
      ),
    );

    await journalStore.save(entry);
    final graph = await graphStore.reconcile(await journalStore.loadAll());
    await hybridAiRouter.indexPersistedEntry(entry, graph);
    var e2eeQueued = false;
    final sync = syncEngine;
    if (sync != null && await sync.identity.isEnabled) {
      await sync.recordTranscripts([entry]);
      await sync.recordGraphSnapshot(graph);
      e2eeQueued = true;
    }
    return ConversationIngestionResult(
      entry: entry,
      graph: graph,
      summary: summary,
      e2eeQueued: e2eeQueued,
    );
  }
}

enum VoiceConversationRole { user, assistant }

class VoiceConversationTranscriptLine {
  const VoiceConversationTranscriptLine({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final VoiceConversationRole role;
  final String text;
  final DateTime createdAt;
}

String _summarize(List<String> userLines) {
  final joined = userLines.join(' ');
  const maximum = 280;
  return joined.length <= maximum
      ? joined
      : '${joined.substring(0, maximum - 1)}…';
}
