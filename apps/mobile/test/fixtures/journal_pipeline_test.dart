import 'dart:io';

import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journal_fixtures.dart';

void main() {
  test('a spoken line is encrypted, restored, and printed', () async {
    const spoken = 'the river was high';

    const passphrase = 'correct horse';
    final service = E2EEncryptionService();
    final entry = await makeJournalEntry(
      text: spoken,
      passphrase: passphrase,
      encryption: service,
    );
    expect(entry.payload.ciphertext, isNot(contains(spoken)));

    final restored = await service.decryptText(entry.payload, passphrase);
    expect(restored, spoken);

    final dir = await Directory.systemTemp.createTemp('journal_pipeline_');
    final file = await BookExporter.save(
      JournalBook(
        title: 'River notes',
        entries: [
          JournalBookEntry(
            dateString: entry.dateString,
            transcript: restored,
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
