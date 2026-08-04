import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../local_storage/encrypted_sqlite_text_codec.dart';
import 'anchor_compute_channel.dart';
import 'offload_policy_engine.dart';

enum RoutedComputeKind { embedding, llama, museSweep }

enum TaskRouteDisposition { local, offloaded, deferred }

typedef AnchorTaskDelegate =
    Future<Map<String, dynamic>?> Function({
      required AnchorComputeJobKind kind,
      required Map<String, dynamic> payload,
      Duration timeout,
    });

final class DeferredComputeTask {
  const DeferredComputeTask({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final RoutedComputeKind kind;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
}

final class TaskRouteResult<T> {
  const TaskRouteResult._(this.disposition, this.value, this.backlogId);

  const TaskRouteResult.local(T value)
    : this._(TaskRouteDisposition.local, value, null);

  const TaskRouteResult.offloaded(T value)
    : this._(TaskRouteDisposition.offloaded, value, null);

  const TaskRouteResult.deferred(String backlogId)
    : this._(TaskRouteDisposition.deferred, null, backlogId);

  final TaskRouteDisposition disposition;
  final T? value;
  final String? backlogId;
}

final class EncryptedComputeBacklog {
  factory EncryptedComputeBacklog({
    required Database database,
    required EncryptedSqliteTextCodec codec,
    bool ownsDatabase = false,
    DateTime Function()? clock,
  }) => EncryptedComputeBacklog._(
    database,
    codec,
    ownsDatabase,
    clock ?? DateTime.now,
  );

  EncryptedComputeBacklog._(
    this._database,
    this.codec,
    this.ownsDatabase,
    this._clock,
  ) {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS sovereign_compute_backlog (
        task_id TEXT PRIMARY KEY,
        task_kind TEXT NOT NULL,
        encrypted_payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<EncryptedComputeBacklog> open({
    required String databasePath,
    required EncryptedSqliteTextCodec codec,
    DateTime Function()? clock,
  }) async {
    await Directory(path.dirname(databasePath)).create(recursive: true);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = NORMAL')
      ..execute('PRAGMA busy_timeout = 3000');
    return EncryptedComputeBacklog(
      database: database,
      codec: codec,
      ownsDatabase: true,
      clock: clock,
    );
  }

  final Database _database;
  final EncryptedSqliteTextCodec codec;
  final bool ownsDatabase;
  final DateTime Function() _clock;
  int _nonce = 0;

  int get length =>
      _database
              .select(
                'SELECT COUNT(*) AS task_count FROM sovereign_compute_backlog',
              )
              .first['task_count']
          as int;

  String enqueue(RoutedComputeKind kind, Map<String, dynamic> payload) {
    final createdAt = _clock().toUtc();
    final id = '${createdAt.microsecondsSinceEpoch}:${++_nonce}:${kind.name}';
    _database.execute(
      'INSERT INTO sovereign_compute_backlog('
      'task_id, task_kind, encrypted_payload, created_at) VALUES (?, ?, ?, ?)',
      [
        id,
        kind.name,
        codec.encode(jsonEncode(payload)),
        createdAt.millisecondsSinceEpoch,
      ],
    );
    return id;
  }

  List<DeferredComputeTask> readAll() => _database
      .select(
        'SELECT task_id, task_kind, encrypted_payload, created_at '
        'FROM sovereign_compute_backlog ORDER BY created_at, task_id',
      )
      .map((row) {
        final kind = RoutedComputeKind.values.byName(
          row['task_kind'] as String,
        );
        final cleartext = codec.decode(row['encrypted_payload'] as String);
        final decoded = jsonDecode(cleartext ?? '');
        if (decoded is! Map) {
          throw const FormatException('Invalid encrypted compute backlog row.');
        }
        return DeferredComputeTask(
          id: row['task_id'] as String,
          kind: kind,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
            isUtc: true,
          ),
          payload: Map<String, dynamic>.from(decoded),
        );
      })
      .toList(growable: false);

  void remove(String taskId) {
    _database.execute(
      'DELETE FROM sovereign_compute_backlog WHERE task_id = ?',
      [taskId],
    );
  }

  void close() {
    if (ownsDatabase) _database.close();
  }
}

final class TaskRouter {
  TaskRouter({
    required this.policy,
    required this.backlog,
    AnchorComputeCoordinator? anchorCompute,
    AnchorTaskDelegate? delegate,
    bool Function()? offloadEnabled,
  }) : assert(anchorCompute != null || delegate != null),
       _delegate = delegate ?? anchorCompute!.delegate,
       _offloadEnabled = offloadEnabled ?? (() => true);

  final OffloadPolicyEngine policy;
  final EncryptedComputeBacklog backlog;
  final AnchorTaskDelegate _delegate;
  final bool Function() _offloadEnabled;
  int _balancedNonce = 0;

  Future<TaskRouteResult<T>> submit<T>({
    required RoutedComputeKind kind,
    required Map<String, dynamic> payload,
    required Future<T> Function() runLocal,
    required T Function(Map<String, dynamic> result) decodeRemote,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final decision = policy.current.policy;
    if (decision == OffloadPolicyState.haltCompute) {
      return TaskRouteResult.deferred(backlog.enqueue(kind, payload));
    }
    if (!_offloadEnabled()) {
      return TaskRouteResult.local(await runLocal());
    }
    if (decision == OffloadPolicyState.preferLocal) {
      return TaskRouteResult.local(await runLocal());
    }
    if (decision == OffloadPolicyState.loadBalance &&
        (_balancedNonce++).isEven) {
      return TaskRouteResult.local(await runLocal());
    }
    try {
      final remote = await _delegate(
        kind: _anchorKind(kind),
        payload: payload,
        timeout: timeout,
      );
      if (remote != null) {
        return TaskRouteResult.offloaded(decodeRemote(remote));
      }
    } on Object {
      if (decision == OffloadPolicyState.loadBalance) {
        return TaskRouteResult.local(await runLocal());
      }
    }
    if (decision == OffloadPolicyState.loadBalance) {
      return TaskRouteResult.local(await runLocal());
    }
    return TaskRouteResult.deferred(backlog.enqueue(kind, payload));
  }

  AnchorComputeJobKind _anchorKind(RoutedComputeKind kind) => switch (kind) {
    RoutedComputeKind.embedding => AnchorComputeJobKind.batchEmbeddings,
    RoutedComputeKind.llama => AnchorComputeJobKind.llamaCouncil,
    RoutedComputeKind.museSweep => AnchorComputeJobKind.museSweep,
  };
}
