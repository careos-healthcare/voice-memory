import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_store.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('enqueue deduplicates active capture ids', () async {
    final sqlite = await openTestAppSqliteDatabase();
    final store = QuickCaptureOutboxStore(AppDatabase.fromSqflite(sqlite.database));
    final captureId = generateUlid();
    final payload = QuickCaptureOutboxPayload(
      captureId: captureId,
      kind: QuickCaptureKind.text,
      text: 'Widget note',
    );

    final firstId = await store.enqueue(payload);
    final secondId = await store.enqueue(
      QuickCaptureOutboxPayload(
        captureId: captureId,
        kind: QuickCaptureKind.text,
        text: 'Updated widget note',
      ),
    );

    expect(secondId, firstId);
    final pending = await store.pending();
    expect(pending, hasLength(1));
    expect(pending.single.payload.text, 'Updated widget note');
  });

  test('markDone removes entry from pending queue', () async {
    final sqlite = await openTestAppSqliteDatabase();
    final store = QuickCaptureOutboxStore(AppDatabase.fromSqflite(sqlite.database));
    final outboxId = await store.enqueue(
      QuickCaptureOutboxPayload(
        captureId: generateUlid(),
        kind: QuickCaptureKind.text,
        text: 'Done me',
      ),
    );

    expect(await store.pendingCount(), 1);
    await store.markProcessing(outboxId);
    await store.markDone(outboxId);
    expect(await store.pendingCount(), 0);
  });
}
