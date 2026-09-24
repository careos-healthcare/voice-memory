import 'package:archiveme_mobile/features/search/vec_search_service.dart';
import 'package:sqflite/sqflite.dart';

/// A note the coach quoted from the local archive.
class CoachCitedNote {
  const CoachCitedNote({
    required this.entryId,
    required this.excerpt,
    required this.score,
  });

  final String entryId;
  final String excerpt;
  final double score;
}

/// A local reply built only from sqlite-vec hits.
class CoachChatReply {
  const CoachChatReply({required this.answer, required this.citations});

  final String answer;
  final List<CoachCitedNote> citations;

  static const empty = CoachChatReply(
    answer: 'No matching notes on this device.',
    citations: [],
  );
}

/// Conversational lookup over encrypted notes. Search stays on sqlite-vec.
class AskTheCoachService {
  AskTheCoachService({
    required this.database,
    required this.embed,
    required this.readNote,
    VecSearchService? vectors,
  }) : _vectors = vectors ?? const VecSearchService();

  final DatabaseExecutor database;
  final List<double> Function(String text) embed;
  final Future<String?> Function(String entryId) readNote;
  final VecSearchService _vectors;

  Future<CoachChatReply> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return CoachChatReply.empty;
    final hits = await _vectors.search(
      db: database,
      queryEmbedding: embed(trimmed),
      limit: 4,
    );
    final citations = <CoachCitedNote>[];
    for (final hit in hits) {
      final note = (await readNote(hit.entryId))?.trim() ?? '';
      if (note.isEmpty) continue;
      citations.add(
        CoachCitedNote(
          entryId: hit.entryId,
          excerpt: note,
          score: hit.score,
        ),
      );
    }
    if (citations.isEmpty) return CoachChatReply.empty;
    final quoted = citations.map((note) => note.excerpt).join(' ');
    return CoachChatReply(
      answer: 'From your notes: $quoted',
      citations: citations,
    );
  }
}
