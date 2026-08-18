import 'package:archiveme_mobile/features/export/journal_bulk_export_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? deletedAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 1, id.hashCode % 20 + 1),
    transcript: transcript,
    durationSeconds: 30,
    deletedAt: deletedAt,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 2,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('export round-trips and excludes soft-deleted entries', () async {
    final db = await AppSqliteDatabase.open(filePath: ':memory:');
    final repo = JournalSqliteRepository(db);
    await repo.mirrorEntireRemoteState([
      _entry(id: 'keep-1', transcript: 'first moment'),
      _entry(id: 'keep-2', transcript: 'second moment'),
      _entry(
        id: 'deleted-1',
        transcript: 'removed moment',
        deletedAt: DateTime.utc(2026, 1, 5),
      ),
    ]);

    final service = JournalBulkExportService(repository: repo);
    final payload = await service.buildExport();
    final roundTrip = JournalBulkExportPayload.fromJsonString(payload.toJsonString());

    expect(roundTrip.entryCount, 2);
    final ids = (roundTrip.entries['entries'] as List)
        .map((row) => (row as Map)['id'] as String)
        .toSet();
    expect(ids, {'keep-1', 'keep-2'});
    expect(ids.contains('deleted-1'), isFalse);
  });
}
