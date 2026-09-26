import 'dart:io';

import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journal_fixtures.dart';

void main() {
  test('a spoken line is encrypted, restored, and printed', () async {
    const spoken = 'the river was high';

    final entry = await makeJournalEntry(text: spoken);
    expect(entry.ciphertext, isNot(contains(spoken)));

    final sealed = await RecordSync.seal(
      accountKey: entry.accountKey,
      recordId: 'fixture',
      kind: SyncRecordKind.entry,
      version: 1,
      updatedAt: DateTime.utc(2026, 3, 8),
      deviceId: 'test',
      plaintext: {'transcript': spoken},
    );
    final restored = await RecordSync.open(
      accountKey: entry.accountKey,
      record: sealed,
    );
    expect(restored['transcript'], spoken);

    final dir = await Directory.systemTemp.createTemp('journal_pipeline_');
    final file = await BookExporter.save(
      JournalBook(
        title: 'River notes',
        entries: [
          JournalBookEntry(
            dateString: entry.dateString,
            transcript: restored['transcript'] as String,
            mood: entry.mood,
            location: entry.location,
            audioQrUrl: entry.audioUrl,
          ),
        ],
      ),
      path: '${dir.path}/journal.pdf',
    );
    expect(await file.length(), greaterThan(0));
  });
}
