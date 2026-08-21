import 'package:archiveme_mobile/storage/sqlite/profiling/sqlite_query_profiler.dart';
import 'package:sqflite/sqflite.dart';

/// Wraps a sqflite [Database] with Timeline + debugPrint profiling.
final class SqliteProfilingDatabase implements Database {
  SqliteProfilingDatabase._(this._delegate);

  final Database _delegate;
  late final _SqliteProfilingExecutor _executor = _SqliteProfilingExecutor(
    _delegate,
    root: this,
  );

  static Database wrapIfEnabled(Database database) {
    if (!SqliteQueryProfiler.enabled || database is SqliteProfilingDatabase) {
      return database;
    }
    return SqliteProfilingDatabase._(database);
  }

  @override
  String get path => _delegate.path;

  @override
  bool get isOpen => _delegate.isOpen;

  @override
  Database get database => this;

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'transaction',
      label: 'transaction${exclusive == true ? ' (exclusive)' : ''}',
      timelineArgs: {'exclusive': exclusive ?? false},
      action: () => _delegate.transaction(
        (txn) => action(_SqliteProfilingTransaction(txn, this)),
        exclusive: exclusive,
      ),
    );
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'transaction',
      label: 'readTransaction',
      action: () => _delegate.readTransaction(
        (txn) => action(_SqliteProfilingTransaction(txn, this)),
      ),
    );
  }

  @override
  Batch batch() => _SqliteProfilingBatch(_delegate.batch());

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      _delegate.devInvokeMethod<T>(method, arguments);

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _delegate.devInvokeSqlMethod<T>(method, sql, arguments);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _executor.execute(sql, arguments);

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _executor.rawInsert(sql, arguments);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _executor.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

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
  }) =>
      _executor.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _executor.rawQuery(sql, arguments);

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _executor.rawQueryCursor(
        sql,
        arguments,
        bufferSize: bufferSize,
      );

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
      _executor.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _executor.rawUpdate(sql, arguments);

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _executor.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _executor.rawDelete(sql, arguments);

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _executor.delete(table, where: where, whereArgs: whereArgs);
}

final class _SqliteProfilingTransaction implements Transaction {
  _SqliteProfilingTransaction(this._delegate, this._root);

  final Transaction _delegate;
  final SqliteProfilingDatabase _root;
  late final _SqliteProfilingExecutor _executor = _SqliteProfilingExecutor(
    _delegate,
    root: _root,
    inTransaction: true,
  );

  @override
  Database get database => _root;

  @override
  Batch batch() => _SqliteProfilingBatch(_delegate.batch());

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _executor.execute(sql, arguments);

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _executor.rawInsert(sql, arguments);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _executor.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

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
  }) =>
      _executor.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _executor.rawQuery(sql, arguments);

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _executor.rawQueryCursor(
        sql,
        arguments,
        bufferSize: bufferSize,
      );

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
      _executor.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _executor.rawUpdate(sql, arguments);

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _executor.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _executor.rawDelete(sql, arguments);

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      _executor.delete(table, where: where, whereArgs: whereArgs);
}

final class _SqliteProfilingExecutor {
  _SqliteProfilingExecutor(
    this._delegate, {
    required this.root,
    this.inTransaction = false,
  });

  final DatabaseExecutor _delegate;
  final SqliteProfilingDatabase root;
  final bool inTransaction;

  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'execute',
      label: SqliteQueryProfiler.previewSql(sql),
      timelineArgs: _timelineArgs(sql: sql, inTransaction: inTransaction),
      action: () => _delegate.execute(sql, arguments),
    );
  }

  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'insert',
      label: SqliteQueryProfiler.previewSql(sql),
      timelineArgs: _timelineArgs(sql: sql, inTransaction: inTransaction),
      action: () => _delegate.rawInsert(sql, arguments),
    );
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'insert',
      label: SqliteQueryProfiler.tableLabel('insert', table),
      timelineArgs: _timelineArgs(table: table, inTransaction: inTransaction),
      action: () => _delegate.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

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
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'query',
      label: SqliteQueryProfiler.tableLabel('query', table),
      timelineArgs: _timelineArgs(table: table, inTransaction: inTransaction),
      action: () => _delegate.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'query',
      label: SqliteQueryProfiler.previewSql(sql),
      timelineArgs: _timelineArgs(sql: sql, inTransaction: inTransaction),
      action: () => _delegate.rawQuery(sql, arguments),
    );
  }

  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'query',
      label: '${SqliteQueryProfiler.previewSql(sql)} (cursor)',
      timelineArgs: _timelineArgs(sql: sql, inTransaction: inTransaction),
      action: () => _delegate.rawQueryCursor(
        sql,
        arguments,
        bufferSize: bufferSize,
      ),
    );
  }

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
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'query',
      label: '${SqliteQueryProfiler.tableLabel('query', table)} (cursor)',
      timelineArgs: _timelineArgs(table: table, inTransaction: inTransaction),
      action: () => _delegate.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      ),
    );
  }

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'update',
      label: SqliteQueryProfiler.previewSql(sql),
      timelineArgs: _timelineArgs(sql: sql, inTransaction: inTransaction),
      action: () => _delegate.rawUpdate(sql, arguments),
    );
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'update',
      label: SqliteQueryProfiler.tableLabel('update', table),
      timelineArgs: _timelineArgs(table: table, inTransaction: inTransaction),
      action: () => _delegate.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'delete',
      label: SqliteQueryProfiler.previewSql(sql),
      timelineArgs: _timelineArgs(sql: sql, inTransaction: inTransaction),
      action: () => _delegate.rawDelete(sql, arguments),
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return SqliteQueryProfiler.profileAsync(
      kind: 'delete',
      label: SqliteQueryProfiler.tableLabel('delete', table),
      timelineArgs: _timelineArgs(table: table, inTransaction: inTransaction),
      action: () => _delegate.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      ),
    );
  }

  Map<String, Object?> _timelineArgs({
    String? sql,
    String? table,
    bool inTransaction = false,
  }) {
    return {
      if (sql case final value?) 'sql': SqliteQueryProfiler.previewSql(value),
      if (table case final value?) 'table': value,
      'inTransaction': inTransaction,
    };
  }
}

final class _SqliteProfilingBatch implements Batch {
  _SqliteProfilingBatch(this._delegate);

  final Batch _delegate;
  var _queuedOperations = 0;

  @override
  int get length => _delegate.length;

  void _trackQueuedOperation() {
    _queuedOperations++;
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) {
    final operationCount = _queuedOperations;
    return SqliteQueryProfiler.profileAsync(
      kind: 'batch',
      label: 'commit ($operationCount ops)',
      timelineArgs: {
        'operations': operationCount,
        'exclusive': exclusive ?? false,
        'noResult': noResult ?? false,
      },
      action: () => _delegate.commit(
        exclusive: exclusive,
        noResult: noResult,
        continueOnError: continueOnError,
      ),
    );
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) {
    final operationCount = _queuedOperations;
    return SqliteQueryProfiler.profileAsync(
      kind: 'batch',
      label: 'apply ($operationCount ops)',
      timelineArgs: {
        'operations': operationCount,
        'noResult': noResult ?? false,
      },
      action: () => _delegate.apply(
        noResult: noResult,
        continueOnError: continueOnError,
      ),
    );
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _trackQueuedOperation();
    _delegate.rawInsert(sql, arguments);
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _trackQueuedOperation();
    _delegate.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _trackQueuedOperation();
    _delegate.rawUpdate(sql, arguments);
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _trackQueuedOperation();
    _delegate.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _trackQueuedOperation();
    _delegate.rawDelete(sql, arguments);
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _trackQueuedOperation();
    _delegate.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _trackQueuedOperation();
    _delegate.execute(sql, arguments);
  }

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
  }) {
    _trackQueuedOperation();
    _delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {
    _trackQueuedOperation();
    _delegate.rawQuery(sql, arguments);
  }
}
