import 'package:drift/backends.dart';
import 'package:drift/drift.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Executes Drift queries against an existing sqflite [Database] handle.
///
/// Does not take ownership of [database] — [AppSqliteDatabase] remains the
/// lifecycle owner.
class WrappedSqfliteExecutor extends QueryExecutor {
  WrappedSqfliteExecutor(this._database);

  final sqflite.Database _database;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => false;

  @override
  Future<void> close() async {}

  @override
  TransactionExecutor beginTransaction() =>
      _WrappedSqfliteTransaction(_database, dialect);

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    for (final arg in statements.arguments) {
      final sql = statements.statements[arg.statementIndex];
      await _database.execute(sql, arg.arguments);
    }
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _database.rawInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _database.rawUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _database.rawDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _database.execute(statement, args ?? const []);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _database.rawQuery(statement, args);
}

class _WrappedSqfliteTransaction extends TransactionExecutor {
  _WrappedSqfliteTransaction(this._database, this.dialect);

  final sqflite.Database _database;

  @override
  final SqlDialect dialect;

  @override
  bool get supportsNestedTransactions => false;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => false;

  @override
  Future<void> close() async {}

  @override
  TransactionExecutor beginTransaction() => this;

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    for (final arg in statements.arguments) {
      final sql = statements.statements[arg.statementIndex];
      await _database.execute(sql, arg.arguments);
    }
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    return _database.rawInsert(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    return _database.rawUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    return _database.rawDelete(statement, args);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _database.execute(statement, args ?? const []);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _database.rawQuery(statement, args);

  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}
}
