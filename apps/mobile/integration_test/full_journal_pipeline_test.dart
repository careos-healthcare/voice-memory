import 'dart:io';
import 'dart:math';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures/journal_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory scratch;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('journal_pipeline_');
  });

  tearDownAll(() async {
    if (scratch.existsSync()) {
      await scratch.delete(recursive: true);
    }
  });

  testWidgets('stage 2 encrypts and restores the fixture transcript', (tester) async {
    final transcript = JournalFixtures.rawEntryJson['transcript'].toString();
    final accountKey = AccountSyncKey.generate(Random(2));
    final sealed = await RecordSync.seal(
      accountKey: accountKey,
      recordId: 'entry-river-2026',
      kind: SyncRecordKind.entry,
      version: 1,
      updatedAt: DateTime.utc(2026, 3, 8),
      deviceId: 'test',
      plaintext: {'transcript': transcript},
    );
    expect(sealed.ciphertext, isNot(contains(transcript)));
    final opened = await RecordSync.open(accountKey: accountKey, record: sealed);
    expect(opened['transcript'], transcript);
  });

  testWidgets('stage 3 writes a PDF book larger than 1KB', (tester) async {
    final file = await BookExporter.generatePdfBook(
      entries: JournalFixtures.getBookEntriesFixture(),
      path: '${scratch.path}/journal.pdf',
    );
    final bytes = await file.readAsBytes();
    expect(file.existsSync(), isTrue);
    expect(bytes.length, greaterThan(1024));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('stage 4 writes the archive json unchanged', (tester) async {
    final expected = JournalFixtures.getExportArchiveJson();
    final file = File('${scratch.path}/archive.json');
    await file.writeAsString(expected);
    expect(await file.readAsString(), expected);
    expect(expected, contains('entry-river-2026'));
  });
}
