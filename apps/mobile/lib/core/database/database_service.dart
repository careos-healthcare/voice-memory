import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/embedding_blob_ranker.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// Which offline corpus a semantic query should read.
enum OfflineCorpus { emotionalTerritories, memoryReminders }

/// One ranked row from [DatabaseService.search].
class CorpusSearchHit {
  const CorpusSearchHit({
    required this.corpus,
    required this.id,
    required this.title,
    required this.snippet,
    required this.score,
  });

  final OfflineCorpus corpus;
  final String id;
  final String title;
  final String snippet;

  /// Cosine similarity. Higher is closer.
  final double score;
}

/// Stored emotional territory. Embeddings are supplied by the existing encoder.
class EmotionalTerritoryRecord {
  const EmotionalTerritoryRecord({
    required this.id,
    required this.slug,
    required this.label,
    required this.defaultLabel,
    required this.kind,
    required this.entryIds,
    required this.mentionCount,
    required this.continuityLines,
    required this.firstAppearance,
    required this.latestAppearance,
    required this.firstAppearanceLabel,
    required this.latestAppearanceLabel,
    this.whatChanged,
    this.whatCameBack,
    this.whatGotQuieter,
  });

  final String id;
  final String slug;
  final String label;
  final String defaultLabel;
  final String kind;
  final List<String> entryIds;
  final int mentionCount;
  final List<String> continuityLines;
  final String? whatChanged;
  final String? whatCameBack;
  final String? whatGotQuieter;
  final String firstAppearance;
  final String latestAppearance;
  final String firstAppearanceLabel;
  final String latestAppearanceLabel;

  String get snippet {
    final lines = continuityLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final joined = lines.join(' ');
    if (joined.isNotEmpty) return joined;
    return label;
  }
}

/// Read-path settings for vector scans on low-power devices.
///
/// [pageSize] is applied before the first tables are created. [mmapSize] is
/// 256MB so warm scans can read the file without copying every page into the
/// heap cache. [cacheSize] is 64MB, expressed as a negative KiB count.
abstract final class DatabaseTuning {
  static const pageSize = 8192;
  static const mmapSize = 268435456;
  static const cacheSize = -64000;

  static void apply(sql.Database db, {int? mmapSize}) {
    db
      ..execute('PRAGMA page_size = $pageSize')
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = NORMAL')
      ..execute('PRAGMA cache_size = $cacheSize')
      ..execute('PRAGMA mmap_size = ${mmapSize ?? DatabaseTuning.mmapSize}');
  }
}

/// SQL predicate applied before cosine distance runs.
class CorpusSearchFilter {
  const CorpusSearchFilter({this.kind, this.from, this.to});

  /// Matches the `kind` column.
  final String? kind;

  /// Inclusive lower bound on `latest_appearance` (`YYYY-MM-DD`).
  final String? from;

  /// Inclusive upper bound on `first_appearance` (`YYYY-MM-DD`).
  final String? to;

  bool get isEmpty =>
      (kind == null || kind!.trim().isEmpty) &&
      (from == null || from!.trim().isEmpty) &&
      (to == null || to!.trim().isEmpty);
}

/// Stored memory reminder. Embeddings are supplied by the existing encoder.
class MemoryReminderRecord {
  const MemoryReminderRecord({
    required this.id,
    required this.text,
    required this.kind,
    required this.strength,
    required this.href,
    required this.context,
    this.pastQuote,
    this.currentQuote,
    this.pastEntryId,
    this.entryId,
    this.pastDateLabel,
    this.currentDateLabel,
  });

  final String id;
  final String text;
  final String kind;
  final double strength;
  final String? pastQuote;
  final String? currentQuote;
  final String? pastEntryId;
  final String? entryId;
  final String? pastDateLabel;
  final String? currentDateLabel;
  final String href;
  final String context;

  String get snippet {
    final parts = <String>[
      text,
      if (pastQuote != null && pastQuote!.trim().isNotEmpty) pastQuote!.trim(),
      if (currentQuote != null && currentQuote!.trim().isNotEmpty)
        currentQuote!.trim(),
    ];
    return parts.join(' ');
  }
}

/// Offline semantic index for emotional territories and memory reminders.
///
/// Uses the `sqlite3` library. When sqlite-vec is present, nearest neighbors
/// come from a `vec0` cosine table. Otherwise ranking uses the float32 blob
/// column. This service stores vectors; it does not run a second embedder.
class DatabaseService {
  DatabaseService(this._db, {bool? vecReady})
    : _vecReady = vecReady ?? _probeVec(_db) {
    DatabaseTuning.apply(_db);
    _createTables();
  }

  /// Opens [path], creating parent usage is the caller's job.
  factory DatabaseService.openFile(String path) {
    return DatabaseService(sql.sqlite3.open(path));
  }

  /// In-memory database for tests and for a process that has not opened a file.
  factory DatabaseService.openMemory() {
    return DatabaseService(sql.sqlite3.openInMemory());
  }

  static const territoryTable = 'emotional_territories';
  static const territoryVecTable = 'emotional_territory_vec';
  static const reminderTable = 'memory_reminders';
  static const reminderVecTable = 'memory_reminder_vec';

  final sql.Database _db;
  final bool _vecReady;

  bool get vecReady => _vecReady;

  int get pageSize => _pragmaInt('page_size');

  int get mmapSize => _pragmaInt('mmap_size');

  int get cacheSize => _pragmaInt('cache_size');

  /// 1 is NORMAL.
  int get synchronous => _pragmaInt('synchronous');

  String get journalMode => '${_pragmaValue('journal_mode')}';

  void dispose() {
    _db.close();
  }

  void upsertTerritory(
    EmotionalTerritoryRecord record,
    List<double> embedding,
  ) {
    final vector = _requireEmbedding(embedding);
    final blob = _pack(vector);
    _db.execute('BEGIN');
    try {
      _db.execute(
        '''
        INSERT INTO $territoryTable (
          id, slug, label, default_label, kind, entry_ids, mention_count,
          continuity_lines, what_changed, what_came_back, what_got_quieter,
          first_appearance, latest_appearance, first_appearance_label,
          latest_appearance_label, snippet, embedding
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          slug = excluded.slug,
          label = excluded.label,
          default_label = excluded.default_label,
          kind = excluded.kind,
          entry_ids = excluded.entry_ids,
          mention_count = excluded.mention_count,
          continuity_lines = excluded.continuity_lines,
          what_changed = excluded.what_changed,
          what_came_back = excluded.what_came_back,
          what_got_quieter = excluded.what_got_quieter,
          first_appearance = excluded.first_appearance,
          latest_appearance = excluded.latest_appearance,
          first_appearance_label = excluded.first_appearance_label,
          latest_appearance_label = excluded.latest_appearance_label,
          snippet = excluded.snippet,
          embedding = excluded.embedding
        ''',
        [
          record.id,
          record.slug,
          record.label,
          record.defaultLabel,
          record.kind,
          jsonEncode(record.entryIds),
          record.mentionCount,
          jsonEncode(record.continuityLines),
          record.whatChanged,
          record.whatCameBack,
          record.whatGotQuieter,
          record.firstAppearance,
          record.latestAppearance,
          record.firstAppearanceLabel,
          record.latestAppearanceLabel,
          record.snippet,
          blob,
        ],
      );
      _replaceVecRow(
        table: territoryVecTable,
        idColumn: 'territory_id',
        id: record.id,
        blob: blob,
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void upsertReminder(MemoryReminderRecord record, List<double> embedding) {
    final vector = _requireEmbedding(embedding);
    final blob = _pack(vector);
    _db.execute('BEGIN');
    try {
      _db.execute(
        '''
        INSERT INTO $reminderTable (
          id, text, kind, strength, past_quote, current_quote, past_entry_id,
          entry_id, past_date_label, current_date_label, href, context,
          snippet, embedding
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          text = excluded.text,
          kind = excluded.kind,
          strength = excluded.strength,
          past_quote = excluded.past_quote,
          current_quote = excluded.current_quote,
          past_entry_id = excluded.past_entry_id,
          entry_id = excluded.entry_id,
          past_date_label = excluded.past_date_label,
          current_date_label = excluded.current_date_label,
          href = excluded.href,
          context = excluded.context,
          snippet = excluded.snippet,
          embedding = excluded.embedding
        ''',
        [
          record.id,
          record.text,
          record.kind,
          record.strength,
          record.pastQuote,
          record.currentQuote,
          record.pastEntryId,
          record.entryId,
          record.pastDateLabel,
          record.currentDateLabel,
          record.href,
          record.context,
          record.snippet,
          blob,
        ],
      );
      _replaceVecRow(
        table: reminderVecTable,
        idColumn: 'reminder_id',
        id: record.id,
        blob: blob,
      );
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void deleteTerritory(String id) {
    _db.execute('DELETE FROM $territoryTable WHERE id = ?', [id]);
    if (_vecReady) {
      _db.execute('DELETE FROM $territoryVecTable WHERE territory_id = ?', [
        id,
      ]);
    }
  }

  void deleteReminder(String id) {
    _db.execute('DELETE FROM $reminderTable WHERE id = ?', [id]);
    if (_vecReady) {
      _db.execute('DELETE FROM $reminderVecTable WHERE reminder_id = ?', [id]);
    }
  }

  /// Nearest territories, reminders, or both, ordered by cosine similarity.
  ///
  /// [filter] is applied in SQL before any distance math, so rows outside the
  /// date range or kind are never compared.
  Future<List<CorpusSearchHit>> search({
    required List<double> queryEmbedding,
    int limit = 8,
    OfflineCorpus? corpus,
    CorpusSearchFilter? filter,
  }) async {
    final query = _requireEmbedding(queryEmbedding);
    if (limit <= 0) return const [];
    final corpora = corpus == null
        ? OfflineCorpus.values
        : <OfflineCorpus>[corpus];
    final hits = <CorpusSearchHit>[];
    for (final item in corpora) {
      hits.addAll(await _searchCorpus(item, query, limit, filter));
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.id.compareTo(b.id);
    });
    if (hits.length <= limit) return hits;
    return hits.sublist(0, limit);
  }

  Future<List<CorpusSearchHit>> _searchCorpus(
    OfflineCorpus corpus,
    List<double> query,
    int limit,
    CorpusSearchFilter? filter,
  ) async {
    final table = corpus == OfflineCorpus.emotionalTerritories
        ? territoryTable
        : reminderTable;
    final vecTable = corpus == OfflineCorpus.emotionalTerritories
        ? territoryVecTable
        : reminderVecTable;
    final idColumn = corpus == OfflineCorpus.emotionalTerritories
        ? 'territory_id'
        : 'reminder_id';
    final titleColumn = corpus == OfflineCorpus.emotionalTerritories
        ? 'label'
        : 'text';

    final narrowed = _candidateWhere(filter, corpus);
    final vecIds = narrowed.where.isEmpty
        ? _vecNeighbors(
            table: vecTable,
            idColumn: idColumn,
            query: query,
            limit: limit,
          )
        : null;
    if (vecIds != null && vecIds.isNotEmpty) {
      return _hitsForIds(
        corpus: corpus,
        table: table,
        titleColumn: titleColumn,
        ranked: vecIds,
      );
    }

    final rows = _db.select(
      'SELECT id, embedding FROM $table ${narrowed.where}',
      narrowed.args,
    );
    final blobs = <EmbeddingBlobRow>[
      for (final row in rows)
        if (row['embedding'] is Uint8List)
          EmbeddingBlobRow(entryId: row['id'] as String, blob: _asBytes(row)),
    ];
    final ranked = await EmbeddingBlobRanker.rank(
      queryEmbedding: query,
      rows: blobs,
      limit: limit,
    );
    return _hitsForIds(
      corpus: corpus,
      table: table,
      titleColumn: titleColumn,
      ranked: [
        for (final hit in ranked)
          (id: hit.entryId, score: hit.cosineSimilarity),
      ],
    );
  }

  List<CorpusSearchHit> _hitsForIds({
    required OfflineCorpus corpus,
    required String table,
    required String titleColumn,
    required List<({String id, double score})> ranked,
  }) {
    if (ranked.isEmpty) return const [];
    final hits = <CorpusSearchHit>[];
    for (final item in ranked) {
      final rows = _db.select(
        'SELECT $titleColumn AS title, snippet FROM $table WHERE id = ?',
        [item.id],
      );
      if (rows.isEmpty) continue;
      hits.add(
        CorpusSearchHit(
          corpus: corpus,
          id: item.id,
          title: rows.first['title'] as String? ?? '',
          snippet: rows.first['snippet'] as String? ?? '',
          score: item.score,
        ),
      );
    }
    return hits;
  }

  List<({String id, double score})>? _vecNeighbors({
    required String table,
    required String idColumn,
    required List<double> query,
    required int limit,
  }) {
    if (!_vecReady) return null;
    try {
      final rows = _db.select(
        '''
        SELECT $idColumn AS id, distance
        FROM $table
        WHERE embedding MATCH ?
        ORDER BY distance
        LIMIT ?
        ''',
        [_pack(query), limit],
      );
      return [
        for (final row in rows)
          (
            id: row['id'] as String,
            score: 1 - ((row['distance'] as num?)?.toDouble() ?? 1),
          ),
      ];
    } on Object {
      return null;
    }
  }

  void _replaceVecRow({
    required String table,
    required String idColumn,
    required String id,
    required Uint8List blob,
  }) {
    if (!_vecReady) return;
    _db.execute('DELETE FROM $table WHERE $idColumn = ?', [id]);
    _db.execute(
      'INSERT INTO $table($idColumn, embedding) VALUES (?, ?)',
      [id, blob],
    );
  }

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS $territoryTable (
        id TEXT PRIMARY KEY,
        slug TEXT NOT NULL,
        label TEXT NOT NULL,
        default_label TEXT NOT NULL,
        kind TEXT NOT NULL,
        entry_ids TEXT NOT NULL,
        mention_count INTEGER NOT NULL,
        continuity_lines TEXT NOT NULL,
        what_changed TEXT,
        what_came_back TEXT,
        what_got_quieter TEXT,
        first_appearance TEXT NOT NULL,
        latest_appearance TEXT NOT NULL,
        first_appearance_label TEXT NOT NULL,
        latest_appearance_label TEXT NOT NULL,
        snippet TEXT NOT NULL,
        embedding BLOB NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS $reminderTable (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        kind TEXT NOT NULL,
        strength REAL NOT NULL,
        past_quote TEXT,
        current_quote TEXT,
        past_entry_id TEXT,
        entry_id TEXT,
        past_date_label TEXT,
        current_date_label TEXT,
        href TEXT NOT NULL,
        context TEXT NOT NULL,
        snippet TEXT NOT NULL,
        embedding BLOB NOT NULL
      )
    ''');
    if (!_vecReady) return;
    final width = localTranscriptEmbeddingDimensions;
    try {
      _db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $territoryVecTable USING vec0(
          territory_id TEXT PRIMARY KEY,
          embedding float[$width] distance_metric=cosine
        )
      ''');
      _db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS $reminderVecTable USING vec0(
          reminder_id TEXT PRIMARY KEY,
          embedding float[$width] distance_metric=cosine
        )
      ''');
    } on Object {
      // Probe succeeded but vec0 DDL failed. Blob ranking still answers queries.
    }
  }

  List<double> _requireEmbedding(List<double> embedding) {
    if (embedding.length != localTranscriptEmbeddingDimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'expected $localTranscriptEmbeddingDimensions dimensions',
      );
    }
    return _normalize(embedding);
  }

  int _pragmaInt(String name) {
    final value = _pragmaValue(name);
    if (value is int) return value;
    return int.parse('$value');
  }

  Object? _pragmaValue(String name) {
    return _db.select('PRAGMA $name').first.values.first;
  }

  ({String where, List<Object?> args}) _candidateWhere(
    CorpusSearchFilter? filter,
    OfflineCorpus corpus,
  ) {
    if (filter == null || filter.isEmpty) {
      return (where: '', args: const []);
    }
    final clauses = <String>[];
    final args = <Object?>[];
    final kind = filter.kind?.trim();
    if (kind != null && kind.isNotEmpty) {
      clauses.add('kind = ?');
      args.add(kind);
    }
    if (corpus == OfflineCorpus.emotionalTerritories) {
      final from = filter.from?.trim();
      final to = filter.to?.trim();
      if (from != null && from.isNotEmpty) {
        clauses.add('latest_appearance >= ?');
        args.add(from);
      }
      if (to != null && to.isNotEmpty) {
        clauses.add('first_appearance <= ?');
        args.add(to);
      }
    }
    if (clauses.isEmpty) return (where: '', args: const []);
    return (where: 'WHERE ${clauses.join(' AND ')}', args: args);
  }

  static bool _probeVec(sql.Database db) {
    try {
      db.select('SELECT vec_version()');
      return true;
    } on Object {
      return false;
    }
  }

  static List<double> _normalize(List<double> values) {
    var norm = 0.0;
    for (final value in values) {
      norm += value * value;
    }
    if (norm == 0) return List<double>.from(values);
    final scale = 1 / math.sqrt(norm);
    return [for (final value in values) value * scale];
  }

  static Uint8List _pack(List<double> values) {
    final floats = Float32List.fromList(values);
    return Uint8List.fromList(floats.buffer.asUint8List());
  }

  static Uint8List _asBytes(sql.Row row) {
    final value = row['embedding'];
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    throw StateError('embedding column was not a blob');
  }
}
