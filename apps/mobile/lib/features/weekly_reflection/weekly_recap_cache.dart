import 'dart:convert';

import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:sqflite/sqflite.dart';

class WeeklyRecapCache {
  WeeklyRecapCache(this._database);

  final Database _database;

  static Future<WeeklyRecapCache> open(String path) async {
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE weekly_recaps (week_key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
      },
    );
    return WeeklyRecapCache(database);
  }

  Future<void> save(WeeklyRecap recap) {
    return _database.insert(
      'weekly_recaps',
      {'week_key': recap.weekKey, 'payload': jsonEncode(recap.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WeeklyRecap?> read(String weekKey) async {
    final rows = await _database.query(
      'weekly_recaps',
      where: 'week_key = ?',
      whereArgs: [weekKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload = rows.first['payload'];
    if (payload is! String) return null;
    return WeeklyRecap.fromJson(
      Map<String, Object?>.from(jsonDecode(payload) as Map),
    );
  }

  Future<void> close() => _database.close();
}
