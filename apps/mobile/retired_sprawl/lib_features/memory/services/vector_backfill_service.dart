import 'dart:async';
import 'dart:isolate';

import 'package:archiveme_mobile/features/memory/services/embedding_service.dart';
import 'package:archiveme_mobile/features/memory/services/local_vector_db.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Embeds journal text after launch, without waiting for the next save.
class VectorBackfillService {
  VectorBackfillService({
    required LocalVectorDb db,
    Future<List<double>> Function(MiniLmEncoding encoding)? embed,
    Future<String> Function()? loadVocab,
    this.batchSize = 8,
  }) : _db = db,
       _embed = embed,
       _loadVocab = loadVocab;

  final LocalVectorDb _db;
  final Future<List<double>> Function(MiniLmEncoding encoding)? _embed;
  final Future<String> Function()? _loadVocab;
  final int batchSize;

  static var _booted = false;

  /// Starts one background pass once the journal database is open.
  static void startOnBoot() {
    if (_booted || !AppServices.isInitialized) return;
    _booted = true;
    unawaited(_boot());
  }

  static Future<void> _boot() async {
    try {
      final db = LocalVectorDb(AppServices.instance.sqliteDatabase.database);
      final entries = await AppServices.instance.journal.loadAll();
      await VectorBackfillService(db: db).backfillEntries(entries);
    } on Object {
      return;
    }
  }

  /// Removes vectors for a deleted entry, or embeds its chunks.
  static Future<void> onEntrySaved(JournalEntry entry) async {
    if (!AppServices.isInitialized) return;
    final db = LocalVectorDb(AppServices.instance.sqliteDatabase.database);
    if (entry.isDeleted) {
      await db.deleteEntry(entry.id);
      return;
    }
    await VectorBackfillService(db: db).backfillEntries([entry]);
  }

  Future<int> backfillEntries(List<JournalEntry> entries) {
    return backfillChunks([
      for (final entry in entries) ...chunksFor(entry),
    ]);
  }

  Future<int> backfillChunks(List<VectorChunk> chunks) async {
    final done = await _db.storedKeys();
    final pending = [
      for (final chunk in chunks)
        if (chunk.text.trim().isNotEmpty &&
            !done.contains('${chunk.entryId}:${chunk.chunkIndex}'))
          chunk,
    ];
    if (pending.isEmpty) return 0;
    await _db.ensure();
    final vocab = await (_loadVocab ?? EmbeddingService.loadVocabText)();
    var stored = 0;
    for (var start = 0; start < pending.length; start += batchSize) {
      final end = mathMin(start + batchSize, pending.length);
      final batch = pending.sublist(start, end);
      final texts = [for (final chunk in batch) chunk.text];
      final encoded = await Isolate.run(
        () => WordPieceTokenizer.encodeAll(vocab, texts),
      );
      for (var i = 0; i < batch.length; i++) {
        final vector = await _vectorFor(
          MiniLmEncoding.fromMap(Map<String, Object?>.from(encoded[i])),
        );
        if (vector.length != LocalVectorDb.dimensions) continue;
        await _db.write(batch[i], vector);
        stored += 1;
      }
    }
    return stored;
  }

  Future<List<double>> _vectorFor(MiniLmEncoding encoding) async {
    final injected = _embed;
    if (injected != null) return injected(encoding);
    final service = await EmbeddingService.open();
    return service.embedEncoding(encoding);
  }
}

int mathMin(int a, int b) => a < b ? a : b;

/// Sentences of [entry], with an audio offset for each chunk.
List<VectorChunk> chunksFor(JournalEntry entry) {
  final text = entry.transcript.trim();
  if (entry.id.isEmpty || text.isEmpty || entry.isDeleted) return const [];
  final sentences = _sentences(text);
  final durationMs = entry.durationSeconds * 1000;
  var searchFrom = 0;
  final chunks = <VectorChunk>[];
  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    final at = text.indexOf(sentence, searchFrom);
    final offset = at < 0 ? 0 : at;
    if (at >= 0) searchFrom = at + sentence.length;
    final startTimeMs = text.isEmpty
        ? 0
        : ((offset / text.length) * durationMs).round();
    chunks.add(
      VectorChunk(
        entryId: entry.id,
        chunkIndex: i,
        text: sentence,
        startTimeMs: startTimeMs,
      ),
    );
  }
  return chunks;
}

List<String> _sentences(String transcript) {
  final parts = transcript.split(RegExp(r'(?<=[.!?])\s+'));
  final sentences = [
    for (final part in parts)
      if (part.trim().isNotEmpty) part.trim(),
  ];
  return sentences.isEmpty ? [transcript] : sentences;
}
