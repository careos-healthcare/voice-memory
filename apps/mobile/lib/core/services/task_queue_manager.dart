import 'package:sqflite/sqflite.dart';

/// A deferred vector-index or P2P sync job.
class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.kind,
    required this.entryId,
    required this.payload,
    required this.status,
    this.enqueuedAt,
  });

  static const kindVectorIndex = 'vector_index';
  static const kindP2pSync = 'p2p_sync';
  static const statusPending = 'pending';
  static const statusDone = 'done';

  final String id;
  final String kind;
  final String entryId;
  final String payload;
  final String status;

  /// Milliseconds since epoch. Older jobs run first.
  final int? enqueuedAt;
}

/// Holds embedding and sync requests until charging or Wi-Fi is available.
abstract class TaskQueueManager {
  Future<void> enqueue(BackgroundTask task);

  Future<List<BackgroundTask>> pending();

  Future<void> complete(String id);
}

class MemoryTaskQueue implements TaskQueueManager {
  final Map<String, BackgroundTask> _tasks = {};

  @override
  Future<void> complete(String id) async {
    final task = _tasks[id];
    if (task == null) return;
    _tasks[id] = BackgroundTask(
      id: task.id,
      kind: task.kind,
      entryId: task.entryId,
      payload: task.payload,
      status: BackgroundTask.statusDone,
      enqueuedAt: task.enqueuedAt,
    );
  }

  @override
  Future<void> enqueue(BackgroundTask task) async {
    _tasks[task.id] = BackgroundTask(
      id: task.id,
      kind: task.kind,
      entryId: task.entryId,
      payload: task.payload,
      status: task.status,
      enqueuedAt: task.enqueuedAt ?? _stamp(),
    );
  }

  @override
  Future<List<BackgroundTask>> pending() async {
    final pending = [
      for (final task in _tasks.values)
        if (task.status == BackgroundTask.statusPending) task,
    ]..sort(_byAge);
    return pending;
  }

  static int _stamp() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static int _byAge(BackgroundTask a, BackgroundTask b) {
    final clock = (a.enqueuedAt ?? 0).compareTo(b.enqueuedAt ?? 0);
    if (clock != 0) return clock;
    return a.id.compareTo(b.id);
  }
}

/// Persists jobs with `status = 'pending'` until a drain cycle finishes them.
class SqliteTaskQueue implements TaskQueueManager {
  SqliteTaskQueue(this._db);

  final Database _db;

  static const table = 'background_task_queue';

  Future<void> ensureTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        enqueued_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    final info = await _db.rawQuery('PRAGMA table_info($table)');
    final columns = <String>{
      for (final row in info) '${row['name']}',
    };
    if (!columns.contains('enqueued_at')) {
      await _db.execute(
        'ALTER TABLE $table ADD COLUMN enqueued_at INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  @override
  Future<void> enqueue(BackgroundTask task) async {
    await ensureTable();
    await Future<void>.delayed(Duration.zero);
    await _db.insert(table, {
      'id': task.id,
      'kind': task.kind,
      'entry_id': task.entryId,
      'payload': task.payload,
      'status': task.status,
      'enqueued_at':
          task.enqueuedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<BackgroundTask>> pending() async {
    await ensureTable();
    final rows = await _db.query(
      table,
      where: 'status = ?',
      whereArgs: [BackgroundTask.statusPending],
      orderBy: 'enqueued_at ASC, id ASC',
    );
    return [
      for (final row in rows)
        BackgroundTask(
          id: row['id']! as String,
          kind: row['kind']! as String,
          entryId: row['entry_id']! as String,
          payload: row['payload']! as String,
          status: row['status']! as String,
          enqueuedAt: (row['enqueued_at'] as num?)?.toInt(),
        ),
    ];
  }

  @override
  Future<void> complete(String id) async {
    await ensureTable();
    await Future<void>.delayed(Duration.zero);
    await _db.update(
      table,
      {'status': BackgroundTask.statusDone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
