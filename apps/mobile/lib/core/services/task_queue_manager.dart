import 'package:sqflite/sqflite.dart';

/// A deferred vector-index or P2P sync job.
class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.kind,
    required this.entryId,
    required this.payload,
    required this.status,
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
}

/// Holds embedding and sync requests until power and Wi-Fi are both available.
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
    );
  }

  @override
  Future<void> enqueue(BackgroundTask task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<List<BackgroundTask>> pending() async {
    return [
      for (final task in _tasks.values)
        if (task.status == BackgroundTask.statusPending) task,
    ];
  }
}

/// Persists jobs with `status = 'pending'` until a drain cycle finishes them.
class SqliteTaskQueue implements TaskQueueManager {
  SqliteTaskQueue(this._db);

  final Database _db;

  static const table = 'background_task_queue';

  Future<void> ensureTable() {
    return _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<void> enqueue(BackgroundTask task) async {
    await ensureTable();
    await _db.insert(table, {
      'id': task.id,
      'kind': task.kind,
      'entry_id': task.entryId,
      'payload': task.payload,
      'status': task.status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<BackgroundTask>> pending() async {
    await ensureTable();
    final rows = await _db.query(
      table,
      where: 'status = ?',
      whereArgs: [BackgroundTask.statusPending],
    );
    return [
      for (final row in rows)
        BackgroundTask(
          id: row['id']! as String,
          kind: row['kind']! as String,
          entryId: row['entry_id']! as String,
          payload: row['payload']! as String,
          status: row['status']! as String,
        ),
    ];
  }

  @override
  Future<void> complete(String id) async {
    await ensureTable();
    await _db.update(
      table,
      {'status': BackgroundTask.statusDone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
