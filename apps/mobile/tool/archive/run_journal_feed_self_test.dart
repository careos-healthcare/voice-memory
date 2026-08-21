import 'dart:convert';
import 'dart:io' show stdout;
import 'storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Paginated journal SQLite smoke tests runnable without compiling the full app.
///
/// Run from apps/mobile: `dart run tool/run_journal_feed_self_test.dart`
Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await openTestAppSqliteDatabase();
  final sqlite = JournalSqliteRepository(db);

  JournalEntry entry({
    required String id,
    required DateTime createdAt,
    required String transcript,
  }) {
    return JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: 12,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 1,
        recurringThemes: ['work'],
        exactLanguagePattern: 'pattern',
        concreteObservation: 'observation',
        repeatedSignal: 'signal',
      ),
    );
  }

  final entries = List.generate(
    45,
    (index) => entry(
      id: 'entry-$index',
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
      transcript: index.isEven ? 'even moment $index' : 'odd moment $index',
    ),
  );

  await sqlite.mirrorEntireRemoteState(entries);
  assert(await sqlite.countActive() == 45);

  final firstPage = await sqlite.fetchPage(offset: 0);
  assert(firstPage.length == JournalSqliteRepository.defaultPageSize);
  assert(firstPage.first.id == 'entry-44');

  final secondPage = await sqlite.fetchPage(
    offset: JournalSqliteRepository.defaultPageSize,
  );
  assert(secondPage.length == JournalSqliteRepository.defaultPageSize);

  final thirdPage = await sqlite.fetchPage(
    offset: JournalSqliteRepository.defaultPageSize * 2,
  );
  assert(thirdPage.length == 5);

  final filteredCount = await sqlite.countActive(searchQuery: 'even');
  assert(filteredCount == 23);

  final filteredPage = await sqlite.fetchPage(
    offset: 0,
    searchQuery: 'even',
  );
  assert(filteredPage.every((row) => row.transcript.contains('even')));

  final roundTrip = firstPage.first.toJson();
  final decoded = JournalEntry.fromJson(
    Map<String, dynamic>.from(jsonDecode(jsonEncode(roundTrip)) as Map),
  );
  assert(decoded.id == firstPage.first.id);

  await AppSqliteDatabase.resetForTest();
  stdout.writeln('OK: journal feed sqlite self-tests passed');
}