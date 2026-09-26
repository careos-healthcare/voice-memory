import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/memory/entry_embedding_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Past moments that use the same words as a newly saved entry.
class RelatedEntriesService {
  RelatedEntriesService(this._store);

  final EntryEmbeddingStore _store;

  /// Cosine matches below this stay off the receipt and the entry.
  static const similarityThreshold = 0.55;

  static const minimumAge = Duration(days: 7);
  static const maxResults = 3;

  Future<List<SimilarEntry>> relatedTo(
    JournalEntry entry, {
    required List<JournalEntry> candidates,
    DateTime? now,
    List<({String word, int startSeconds})>? wordTimestampsFor,
  }) async {
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) return const [];
    final stored = await _store.read(entry.id);
    final query = stored?.vector ??
        EntryEmbeddingStore.localNgramEmbedding(transcript);
    final hidden = await _store.hiddenEntryIds();
    final vectors = await _store.readAll();
    final byId = {for (final row in vectors) row.entryId: row.vector};
    return select(
      query: query,
      currentId: entry.id,
      candidates: [
        for (final candidate in candidates)
          if (byId[candidate.id] != null)
            (entry: candidate, vector: byId[candidate.id]!),
      ],
      hiddenEntryIds: hidden,
      now: now,
      embed: EntryEmbeddingStore.localNgramEmbedding,
      wordTimestamps: wordTimestampsFor == null
          ? null
          : (_) => wordTimestampsFor,
    );
  }

  /// Up to [maxResults] entries older than [minimumAge].
  ///
  /// Deleted entries and entries the person hid are left out.
  List<SimilarEntry> select({
    required List<double> query,
    required String currentId,
    required List<({JournalEntry entry, List<double> vector})> candidates,
    required Set<String> hiddenEntryIds,
    DateTime? now,
    List<double> Function(String text) embed =
        EntryEmbeddingStore.localNgramEmbedding,
    List<({String word, int startSeconds})>? Function(JournalEntry entry)?
    wordTimestamps,
  }) {
    final moment = now ?? DateTime.now().toUtc();
    final scored = <SimilarEntry>[];
    for (final candidate in candidates) {
      final entry = candidate.entry;
      if (entry.id == currentId || entry.id.isEmpty) continue;
      if (entry.isDeleted) continue;
      if (hiddenEntryIds.contains(entry.id)) continue;
      if (moment.difference(entry.createdAt.toUtc()) < minimumAge) continue;
      final transcript = entry.transcript.trim();
      if (transcript.isEmpty) continue;
      final score = cosineSimilarity(query, candidate.vector);
      if (score < similarityThreshold) continue;
      final sentence = bestVerbatimSentence(transcript, query, embed);
      final stamps = wordTimestamps?.call(entry);
      scored.add(
        SimilarEntry(
          id: entry.id,
          createdAt: entry.createdAt,
          transcript: transcript,
          quote: sentence,
          localAudioPath: entry.localAudioPath,
          startSeconds: sentenceStartSeconds(sentence, stamps),
          cosineSimilarity: score,
        ),
      );
    }
    scored.sort((a, b) {
      final byScore = b.cosineSimilarity.compareTo(a.cosineSimilarity);
      if (byScore != 0) return byScore;
      return a.id.compareTo(b.id);
    });
    return scored.take(maxResults).toList(growable: false);
  }
}
