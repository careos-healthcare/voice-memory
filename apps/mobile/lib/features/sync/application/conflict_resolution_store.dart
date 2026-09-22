import 'package:sqflite/sqflite.dart';

enum ConflictChoice { useLocal, useRemote, combineBoth }

/// A user's decision for one conflicting entry.
class ConflictDecision {
  const ConflictDecision({
    required this.entryId,
    required this.choice,
    required this.resolvedText,
  });

  final String entryId;
  final ConflictChoice choice;
  final String resolvedText;
}

/// Durable record of a merge. SQLite and in-memory stores share this seam.
abstract class ConflictResolutionStore {
  Future<void> save(ConflictDecision decision);
  Future<ConflictDecision?> read(String entryId);
}

class MemoryConflictResolutionStore implements ConflictResolutionStore {
  final Map<String, ConflictDecision> _saved = {};

  @override
  Future<ConflictDecision?> read(String entryId) async => _saved[entryId];

  @override
  Future<void> save(ConflictDecision decision) async {
    _saved[decision.entryId] = decision;
  }
}

/// Writes the chosen transcript into `conflict_resolutions`.
class SqliteConflictResolutionStore implements ConflictResolutionStore {
  SqliteConflictResolutionStore(this._db);

  final Database _db;

  static const table = 'conflict_resolutions';

  Future<void> ensureTable() {
    return _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        entry_id TEXT PRIMARY KEY,
        choice TEXT NOT NULL,
        resolved_text TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<void> save(ConflictDecision decision) async {
    await ensureTable();
    await _db.insert(table, {
      'entry_id': decision.entryId,
      'choice': decision.choice.name,
      'resolved_text': decision.resolvedText,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<ConflictDecision?> read(String entryId) async {
    await ensureTable();
    final rows = await _db.query(
      table,
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ConflictDecision(
      entryId: row['entry_id']! as String,
      choice: ConflictChoice.values.byName(row['choice']! as String),
      resolvedText: row['resolved_text']! as String,
    );
  }
}
