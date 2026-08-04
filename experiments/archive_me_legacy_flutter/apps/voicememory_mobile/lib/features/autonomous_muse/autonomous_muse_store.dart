import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../services/local_storage/encrypted_sqlite_text_codec.dart';
import 'autonomous_muse_models.dart';

final class AutonomousMuseStore {
  AutonomousMuseStore._(this._database, this._codec);

  final Database _database;
  final EncryptedSqliteTextCodec _codec;
  bool _closed = false;

  static AutonomousMuseStore open({
    required String databasePath,
    required EncryptedSqliteTextCodec codec,
  }) {
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('PRAGMA busy_timeout = 5000')
      ..execute('''
        CREATE TABLE IF NOT EXISTS muse_state (
          key TEXT PRIMARY KEY,
          encrypted_value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS muse_cluster_visits (
          cluster_id TEXT PRIMARY KEY,
          visited_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS muse_runs (
          id TEXT PRIMARY KEY,
          started_at INTEGER NOT NULL,
          completed_at INTEGER,
          status TEXT NOT NULL,
          bridge_count INTEGER NOT NULL DEFAULT 0
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS legacy_bridge_suggestions (
          id TEXT PRIMARY KEY,
          source_node_id TEXT NOT NULL,
          target_node_id TEXT NOT NULL,
          status TEXT NOT NULL,
          confidence REAL NOT NULL,
          encrypted_payload TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          resolved_at INTEGER
        )
      ''')
      ..execute('''
        CREATE INDEX IF NOT EXISTS legacy_bridge_suggestions_status
        ON legacy_bridge_suggestions(status, created_at)
      ''');
    return AutonomousMuseStore._(database, codec);
  }

  MuseGovernance readGovernance() {
    final value = _readJson('governance');
    return value == null
        ? const MuseGovernance()
        : MuseGovernance.fromJson(value);
  }

  void writeGovernance(MuseGovernance value) =>
      _writeJson('governance', value.toJson());

  MuseBriefing? latestBriefing() {
    final value = _readJson('latest_briefing');
    return value == null ? null : MuseBriefing.fromJson(value);
  }

  void saveBriefing(MuseBriefing briefing) =>
      _writeJson('latest_briefing', briefing.toJson());

  LegacySweepProgress readLegacySweepProgress() {
    final value = _readJson('legacy_sweep_progress');
    return value == null
        ? const LegacySweepProgress.idle()
        : LegacySweepProgress.fromJson(value);
  }

  void saveLegacySweepProgress(LegacySweepProgress progress) =>
      _writeJson('legacy_sweep_progress', progress.toJson());

  List<String> readDailyDigestIds(String day) {
    final value = _readJson('legacy_daily_digest_$day');
    return (value?['ids'] as List? ?? const []).whereType<String>().toList();
  }

  void saveDailyDigestIds(String day, Iterable<String> ids) =>
      _writeJson('legacy_daily_digest_$day', {'ids': ids.toSet().toList()});

  void upsertLegacySuggestion(LegacyBridgeSuggestion suggestion) {
    final payload = _codec.encode(jsonEncode(suggestion.toJson()))!;
    _database.execute(
      '''
      INSERT INTO legacy_bridge_suggestions(
        id, source_node_id, target_node_id, status, confidence,
        encrypted_payload, created_at, resolved_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        status = excluded.status,
        confidence = excluded.confidence,
        encrypted_payload = excluded.encrypted_payload,
        resolved_at = excluded.resolved_at
      ''',
      [
        suggestion.id,
        suggestion.sourceNodeId,
        suggestion.targetNodeId,
        suggestion.status.name,
        suggestion.confidenceScore,
        payload,
        suggestion.createdAt.millisecondsSinceEpoch,
        suggestion.resolvedAt?.millisecondsSinceEpoch,
      ],
    );
  }

  List<LegacyBridgeSuggestion> legacySuggestions({
    LegacyBridgeSuggestionStatus? status,
  }) {
    final rows = status == null
        ? _database.select(
            'SELECT encrypted_payload FROM legacy_bridge_suggestions '
            'ORDER BY created_at ASC',
          )
        : _database.select(
            'SELECT encrypted_payload FROM legacy_bridge_suggestions '
            'WHERE status = ? ORDER BY created_at ASC',
            [status.name],
          );
    return List.unmodifiable(
      rows.map((row) {
        final clear = _codec.decode(row['encrypted_payload'] as String);
        return LegacyBridgeSuggestion.fromJson(
          Map<String, dynamic>.from(jsonDecode(clear ?? '{}') as Map),
        );
      }),
    );
  }

  LegacyBridgeSuggestion? legacySuggestion(String id) {
    final rows = _database.select(
      'SELECT encrypted_payload FROM legacy_bridge_suggestions WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final clear = _codec.decode(rows.single['encrypted_payload'] as String);
    return LegacyBridgeSuggestion.fromJson(
      Map<String, dynamic>.from(jsonDecode(clear ?? '{}') as Map),
    );
  }

  bool hasLegacySuggestionPair(String sourceNodeId, String targetNodeId) {
    final rows = _database.select(
      '''
      SELECT 1 FROM legacy_bridge_suggestions
      WHERE (source_node_id = ? AND target_node_id = ?)
         OR (source_node_id = ? AND target_node_id = ?)
      LIMIT 1
      ''',
      [sourceNodeId, targetNodeId, targetNodeId, sourceNodeId],
    );
    return rows.isNotEmpty;
  }

  bool wasBriefingPresented(DateTime localDay) {
    final value = _readJson('last_presented');
    return value?['day'] == _day(localDay);
  }

  void markBriefingPresented(DateTime localDay) =>
      _writeJson('last_presented', {'day': _day(localDay)});

  DateTime? get lastCompletedAt {
    final rows = _database.select(
      'SELECT completed_at FROM muse_runs '
      'WHERE completed_at IS NOT NULL AND status = ? '
      'ORDER BY completed_at DESC LIMIT 1',
      [MuseSweepStatus.completed.name],
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      rows.single['completed_at'] as int,
      isUtc: true,
    );
  }

  Map<String, DateTime> clusterVisits() => {
    for (final row in _database.select(
      'SELECT cluster_id, visited_at FROM muse_cluster_visits',
    ))
      row['cluster_id'] as String: DateTime.fromMillisecondsSinceEpoch(
        row['visited_at'] as int,
        isUtc: true,
      ),
  };

  void markClusterVisited(String clusterId, DateTime visitedAt) {
    if (clusterId.trim().isEmpty) return;
    _database.execute(
      'INSERT INTO muse_cluster_visits(cluster_id, visited_at) VALUES (?, ?) '
      'ON CONFLICT(cluster_id) DO UPDATE SET visited_at = excluded.visited_at',
      [clusterId, visitedAt.toUtc().millisecondsSinceEpoch],
    );
  }

  T transaction<T>(T Function() operation) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      _database.execute('COMMIT');
      return result;
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void beginRun(String id, DateTime startedAt) {
    _database.execute(
      'INSERT INTO muse_runs(id, started_at, status) VALUES (?, ?, ?)',
      [id, startedAt.toUtc().millisecondsSinceEpoch, 'running'],
    );
  }

  void finishRun(
    String id, {
    required DateTime completedAt,
    required MuseSweepStatus status,
    required int bridgeCount,
  }) {
    _database.execute(
      'UPDATE muse_runs SET completed_at = ?, status = ?, bridge_count = ? '
      'WHERE id = ?',
      [
        completedAt.toUtc().millisecondsSinceEpoch,
        status.name,
        bridgeCount,
        id,
      ],
    );
  }

  void clear() => transaction(() {
    _database
      ..execute('DELETE FROM muse_state')
      ..execute('DELETE FROM muse_cluster_visits')
      ..execute('DELETE FROM muse_runs')
      ..execute('DELETE FROM legacy_bridge_suggestions');
  });

  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
  }

  Map<String, dynamic>? _readJson(String key) {
    final rows = _database.select(
      'SELECT encrypted_value FROM muse_state WHERE key = ?',
      [key],
    );
    if (rows.isEmpty) return null;
    final clear = _codec.decode(rows.single['encrypted_value'] as String);
    final value = jsonDecode(clear ?? '');
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  void _writeJson(String key, Map<String, Object?> value) {
    final encoded = _codec.encode(jsonEncode(value));
    _database.execute(
      'INSERT INTO muse_state(key, encrypted_value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET encrypted_value = excluded.encrypted_value, '
      'updated_at = excluded.updated_at',
      [key, encoded, DateTime.now().toUtc().millisecondsSinceEpoch],
    );
  }
}

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
