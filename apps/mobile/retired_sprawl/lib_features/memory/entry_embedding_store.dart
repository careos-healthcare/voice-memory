import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/search/onnx_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_022_entry_embeddings.dart';
import 'package:sqflite/sqflite.dart';

/// On-device sentence vectors for journal memory.
///
/// [OnnxReflectionEmbeddingInference] is used when
/// `assets/models/reflection_encoder.onnx` is present. That graph is the
/// 384-d text encoder (all-MiniLM-L6-v2, quantized ONNX, about 23 MB). The
/// file is not in the repo today, so the store falls back to
/// [localNgramModelVersion], an on-device 384-d encoder that needs no
/// network. Adding the MiniLM asset increases the app by about 23 MB.
class EntryEmbeddingStore {
  EntryEmbeddingStore(
    this._db, {
    Future<List<double>> Function(String text)? embedText,
    this.modelVersion = localNgramModelVersion,
  }) : _embedText = embedText ?? embedTranscript;

  final Database _db;
  final Future<List<double>> Function(String text) _embedText;
  final String modelVersion;

  static const embeddingsTable = Migration022EntryEmbeddings.embeddingsTable;
  static const hiddenEntriesTable =
      Migration022EntryEmbeddings.hiddenEntriesTable;
  static const hiddenLabelsTable = Migration022EntryEmbeddings.hiddenLabelsTable;

  /// On-device stand-in used until the 23 MB MiniLM asset is bundled.
  static const localNgramModelVersion = 'local-ngram-v1';

  /// Model id written when the bundled ONNX encoder runs.
  static const miniLmModelVersion = 'all-MiniLM-L6-v2';

  static const dimensions = ReflectionEmbeddingContract.dimensions;
  static const backfillBatchSize = 20;

  static Future<List<double>> embedTranscript(String text) async {
    final onnx = await OnnxReflectionEmbeddingInference.tryCreateFromAsset();
    if (onnx != null && onnx.producesSemanticVectors) {
      final tensor = ReflectionTextProcessor.buildInputTensor(text);
      return onnx.embed(tensor);
    }
    return localNgramEmbedding(text);
  }

  /// Hashed character trigrams. Repeated wording lands near the same vector.
  static List<double> localNgramEmbedding(String text) {
    final vector = List<double>.filled(dimensions, 0);
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return vector;
    final padded = '  $normalized  ';
    for (var i = 0; i + 3 <= padded.length; i++) {
      final gram = padded.substring(i, i + 3);
      var hash = 2166136261;
      for (final unit in gram.codeUnits) {
        hash ^= unit;
        hash = (hash * 16777619) & 0x7fffffff;
      }
      final index = hash % dimensions;
      vector[index] += hash.isEven ? 1 : -1;
    }
    return _normalize(vector);
  }

  Future<void> ensureTables() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $embeddingsTable (
        entry_id TEXT PRIMARY KEY NOT NULL,
        vector BLOB NOT NULL,
        model_version TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $hiddenEntriesTable (
        entry_id TEXT PRIMARY KEY NOT NULL,
        hidden_at INTEGER NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $hiddenLabelsTable (
        label TEXT PRIMARY KEY NOT NULL,
        hidden_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> remember(JournalEntry entry) async {
    final transcript = entry.transcript.trim();
    if (entry.id.isEmpty || transcript.isEmpty || entry.isDeleted) return;
    await ensureTables();
    final vector = await _embedText(transcript);
    await writeVector(
      entryId: entry.id,
      vector: vector,
      createdAt: entry.createdAt,
      modelVersion: modelVersion,
    );
  }

  Future<void> writeVector({
    required String entryId,
    required List<double> vector,
    required DateTime createdAt,
    String? modelVersion,
  }) async {
    await ensureTables();
    await _db.insert(embeddingsTable, {
      'entry_id': entryId,
      'vector': float32Blob(vector),
      'model_version': modelVersion ?? this.modelVersion,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<StoredEntryEmbedding?> read(String entryId) async {
    await ensureTables();
    final rows = await _db.query(
      embeddingsTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoredEntryEmbedding.fromRow(rows.first);
  }

  Future<List<StoredEntryEmbedding>> readAll() async {
    await ensureTables();
    final rows = await _db.query(embeddingsTable);
    return [for (final row in rows) StoredEntryEmbedding.fromRow(row)];
  }

  /// Embeds up to [batchSize] entries that do not yet have a vector.
  ///
  /// Already-stored ids are skipped, so a later call resumes. [cancelled]
  /// stops the batch before the next entry.
  Future<int> embedMissing(
    List<JournalEntry> entries, {
    int batchSize = backfillBatchSize,
    bool Function()? cancelled,
  }) async {
    await ensureTables();
    final existing = await _db.query(embeddingsTable, columns: ['entry_id']);
    final done = {
      for (final row in existing) row['entry_id'] as String? ?? '',
    };
    var stored = 0;
    for (final entry in entries) {
      if (cancelled?.call() == true) break;
      if (stored >= batchSize) break;
      if (entry.isDeleted || entry.transcript.trim().isEmpty) continue;
      if (done.contains(entry.id)) continue;
      await remember(entry);
      stored += 1;
    }
    return stored;
  }

  Future<void> hideEntry(String entryId) async {
    if (entryId.isEmpty) return;
    await ensureTables();
    await _db.insert(hiddenEntriesTable, {
      'entry_id': entryId,
      'hidden_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<String>> hiddenEntryIds() async {
    await ensureTables();
    final rows = await _db.query(hiddenEntriesTable, columns: ['entry_id']);
    return {
      for (final row in rows)
        if (row['entry_id'] is String) row['entry_id']! as String,
    };
  }

  Future<void> hideLabel(String label) async {
    final key = label.trim().toLowerCase();
    if (key.isEmpty) return;
    await ensureTables();
    await _db.insert(hiddenLabelsTable, {
      'label': key,
      'hidden_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<String>> hiddenLabels() async {
    await ensureTables();
    final rows = await _db.query(hiddenLabelsTable, columns: ['label']);
    return {
      for (final row in rows)
        if (row['label'] is String) row['label']! as String,
    };
  }

  static Uint8List float32Blob(List<double> vector) {
    final floats = Float32List.fromList(vector);
    return Uint8List.view(
      floats.buffer,
      floats.offsetInBytes,
      floats.lengthInBytes,
    );
  }

  static List<double> blobToVector(Uint8List blob) {
    final floats = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ Float32List.bytesPerElement,
    );
    return floats.toList(growable: false);
  }

  static List<double> _normalize(List<double> vector) {
    var norm = 0.0;
    for (final value in vector) {
      norm += value * value;
    }
    norm = math.sqrt(norm);
    if (norm == 0) return vector;
    return [for (final value in vector) value / norm];
  }
}

class StoredEntryEmbedding {
  const StoredEntryEmbedding({
    required this.entryId,
    required this.vector,
    required this.modelVersion,
    required this.createdAt,
  });

  final String entryId;
  final List<double> vector;
  final String modelVersion;
  final DateTime createdAt;

  factory StoredEntryEmbedding.fromRow(Map<String, Object?> row) {
    final blob = row['vector'] as Uint8List? ?? Uint8List(0);
    return StoredEntryEmbedding(
      entryId: row['entry_id'] as String? ?? '',
      vector: EntryEmbeddingStore.blobToVector(blob),
      modelVersion: row['model_version'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
        isUtc: true,
      ),
    );
  }
}

/// Stores a vector after a journal entry is durably saved, then embeds any
/// older entries that are still missing one.
class EntryEmbeddingSaveInterceptor implements JournalSaveInterceptor {
  const EntryEmbeddingSaveInterceptor();

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    if (!AppServices.isInitialized) return;
    try {
      final store = EntryEmbeddingStore(
        AppServices.instance.sqliteDatabase.database,
      );
      await store.remember(entry);
      unawaited(EntryEmbeddingBackfill.instance.pump(store));
    } on Object {
      return;
    }
  }
}

/// Embeds existing entries in batches of 20 while the app is idle.
class EntryEmbeddingBackfill {
  EntryEmbeddingBackfill._();

  static final instance = EntryEmbeddingBackfill._();

  var _cancelled = false;
  var _running = false;

  void cancel() => _cancelled = true;

  void resume() => _cancelled = false;

  Future<void> pump(EntryEmbeddingStore store) async {
    if (_running || _cancelled || !AppServices.isInitialized) return;
    _running = true;
    try {
      final entries = await AppServices.instance.journal.loadAll();
      while (!_cancelled) {
        final stored = await store.embedMissing(
          entries,
          cancelled: () => _cancelled,
        );
        if (stored == 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    } on Object {
      return;
    } finally {
      _running = false;
    }
  }
}

/// Splits a transcript into the sentences the person actually said.
List<String> verbatimSentences(String transcript) {
  final trimmed = transcript.trim();
  if (trimmed.isEmpty) return const [];
  final parts = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
  final sentences = [
    for (final part in parts)
      if (part.trim().isNotEmpty) part.trim(),
  ];
  return sentences.isEmpty ? [trimmed] : sentences;
}

/// The sentence whose vector is closest to [query]. The words are unchanged.
String bestVerbatimSentence(
  String transcript,
  List<double> query,
  List<double> Function(String text) embed,
) {
  final sentences = verbatimSentences(transcript);
  if (sentences.length <= 1) {
    return sentences.isEmpty ? transcript.trim() : sentences.first;
  }
  var best = sentences.first;
  var bestScore = -1.0;
  for (final sentence in sentences) {
    final score = cosineSimilarity(query, embed(sentence));
    if (score > bestScore) {
      bestScore = score;
      best = sentence;
    }
  }
  return best;
}

/// First word-timestamp that falls inside [sentence], when timestamps exist.
int? sentenceStartSeconds(
  String sentence,
  List<({String word, int startSeconds})>? words,
) {
  if (words == null || words.isEmpty) return null;
  final needle = sentence.toLowerCase();
  for (final word in words) {
    final token = word.word.trim().toLowerCase();
    if (token.isEmpty) continue;
    if (needle.contains(token)) return word.startSeconds;
  }
  return null;
}

double cosineSimilarity(List<double> a, List<double> b) {
  final length = math.min(a.length, b.length);
  if (length == 0) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}
