import 'dart:io';

import 'package:archiveme_mobile/features/actionable_memory/actionable_memory_models.dart';
import 'package:archiveme_mobile/features/actionable_memory/actionable_memory_surfacing_service.dart';
import 'package:archiveme_mobile/product/customer_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-09-23T18:00:00.000Z';
  final context = ActionableMemoryContext(
    now: DateTime.parse(now),
    locality: 'Harbor',
    calendarTitle: 'Dinner with Sam',
    focusTerms: const ['walk'],
  );

  test('surfaces an older matching moment and prepares a GPT-5 request', () async {
    final dir = await Directory.systemTemp.createTemp('actionable_memory_');
    addTearDown(() => dir.delete(recursive: true));
    final sqlite = await openTestAppSqliteDatabase(
      filePath: '${dir.path}/journal.sqlite',
    );
    addTearDown(sqlite.close);
    final db = sqlite.database;

    await _insert(
      db,
      id: 'recent',
      at: DateTime.parse('2026-09-23T17:00:00.000Z'),
      transcript: 'A walk along the harbor before dinner.',
    );
    await _insert(
      db,
      id: 'older-walk',
      at: DateTime.parse('2026-03-02T18:10:00.000Z'),
      transcript: 'Left for a walk after lunch.',
      payload: '{"locality":"Harbor"}',
    );
    await _insert(
      db,
      id: 'unrelated',
      at: DateTime.parse('2026-01-04T09:00:00.000Z'),
      transcript: 'Bought new notebooks.',
    );
    await _insert(
      db,
      id: 'locked',
      at: DateTime.parse('2025-06-01T18:00:00.000Z'),
      transcript: 'A long walk I am not ready to open.',
      timeCapsule: true,
      unlockDate: DateTime.parse('2027-01-01T00:00:00.000Z'),
    );

    final outbox = ActionableMemoryOutbox();
    final result = await ActionableMemorySurfacingService(
      notifier: outbox,
    ).surface(db: db, context: context);

    expect(result, isNotNull);
    expect(result!.notification.leadEntryId, 'older-walk');
    expect(result.notification.sourceEntryIds, isNot(contains('locked')));
    expect(result.notification.sourceEntryIds, isNot(contains('recent')));
    expect(result.notification.title, 'You wrote about this before');
    expect(result.notification.body, contains('Left for a walk after lunch.'));
    expect(result.request.model, Gpt5MemorySynthesisRequest.modelId);
    expect(result.request.moments.single['id'], 'older-walk');
    expect(result.readyForRemoteSynthesis, isFalse);
    expect(outbox.latest?.leadEntryId, 'older-walk');
    _expectCustomerLanguage(result.notification.title);
    _expectCustomerLanguage(result.notification.body);
  });

  test('stays quiet when nothing in the current context can match', () async {
    final dir = await Directory.systemTemp.createTemp('actionable_memory_empty_');
    addTearDown(() => dir.delete(recursive: true));
    final sqlite = await openTestAppSqliteDatabase(
      filePath: '${dir.path}/journal.sqlite',
    );
    addTearDown(sqlite.close);

    final surfaced = await ActionableMemorySurfacingService().surface(
      db: sqlite.database,
      context: ActionableMemoryContext(
        now: DateTime.utc(2026, 9, 23, 18),
      ),
    );
    expect(surfaced, isNull);
  });
}

void _expectCustomerLanguage(String text) {
  final lower = text.toLowerCase();
  for (final term in CustomerLanguage.bannedPrimaryUiTerms) {
    expect(lower.contains(term.toLowerCase()), isFalse, reason: term);
  }
}

Future<void> _insert(
  Database db, {
  required String id,
  required DateTime at,
  required String transcript,
  String payload = '{}',
  bool timeCapsule = false,
  DateTime? unlockDate,
}) {
  final millis = at.toUtc().millisecondsSinceEpoch;
  return db.insert('journal_entries', {
    'id': id,
    'created_at': millis,
    'updated_at': millis,
    'deleted_at': null,
    'is_archived': 0,
    'transcript': transcript,
    'has_verified_proof': 0,
    'payload_json': payload,
    'is_time_capsule': timeCapsule ? 1 : 0,
    'unlock_date': unlockDate?.toUtc().millisecondsSinceEpoch,
    'unlock_milestone_entry_count': null,
  });
}
