import 'package:archiveme_mobile/storage/sqlite/profiling/sqlite_profiling_database.dart';
import 'package:archiveme_mobile/storage/sqlite/profiling/sqlite_query_profiler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  tearDown(() {
    SqliteQueryProfiler.enabledOverride = null;
  });

  test('wrapIfEnabled leaves handle unchanged when profiling is disabled', () {
    SqliteQueryProfiler.enabledOverride = false;
    final db = _RecordingDatabase();
    expect(identical(db, SqliteProfilingDatabase.wrapIfEnabled(db)), isTrue);
  });

  test('wrapIfEnabled profiles queries when profiling is enabled', () async {
    SqliteQueryProfiler.enabledOverride = true;
    final recording = _RecordingDatabase();
    final db = SqliteProfilingDatabase.wrapIfEnabled(recording);

    await db.rawQuery('SELECT 1');
    await db.transaction((txn) async {
      await txn.insert('journal_entries', {'id': 'a'});
    });
    final batch = db.batch()
      ..insert('journal_entries', {'id': 'b'})
      ..insert('journal_entries', {'id': 'c'});
    await batch.commit(noResult: true);
    await db.close();

    expect(recording.rawQueryCalls, 1);
    expect(recording.transactionCalls, 1);
    expect(recording.batchCommitCalls, 1);
  });
}

final class _RecordingDatabase implements Database {
  var rawQueryCalls = 0;
  var transactionCalls = 0;
  var batchCommitCalls = 0;

  @override
  String get path => ':memory:';

  @override
  bool get isOpen => true;

  @override
  Database get database => this;

  @override
  Future<void> close() async {}

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    transactionCalls++;
    return action(_RecordingTransaction(this));
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) =>
      transaction(action);

  @override
  Batch batch() => _RecordingBatch(() => batchCommitCalls++);

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) async =>
      throw UnimplementedError();

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) async =>
      throw UnimplementedError();

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async =>
      0;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async =>
      [];

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    rawQueryCalls++;
    return const [{'value': 1}];
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      throw UnimplementedError();

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async =>
      0;

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async =>
      0;
}

final class _RecordingTransaction implements Transaction {
  _RecordingTransaction(this.root);

  final _RecordingDatabase root;

  @override
  Database get database => root;

  @override
  Batch batch() => root.batch();

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async =>
      0;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async =>
      [];

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async =>
      [];

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      throw UnimplementedError();

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async =>
      0;

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async =>
      0;
}

final class _RecordingBatch implements Batch {
  _RecordingBatch(this._onCommit);

  final void Function() _onCommit;
  var _length = 0;

  @override
  int get length => _length;

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    _onCommit();
    return const [];
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) async =>
      commit(noResult: noResult, continueOnError: continueOnError);

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) => _length++;

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _length++;

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) => _length++;

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _length++;

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) => _length++;

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _length++;

  @override
  void execute(String sql, [List<Object?>? arguments]) => _length++;

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => _length++;

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) => _length++;
}
