import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/account_data_portability_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 1, 15, 12),
  transcript: transcript,
  durationSeconds: 12,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 4,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'A concrete observation.',
    repeatedSignal: '',
  ),
);

void main() {
  test('AccountDataPortabilityService builds non-empty ZIP export', () async {
    final dir = Directory.systemTemp.createTempSync('vm_portability_test_');
    final journal = await JournalStore.open('${dir.path}/entries.json');
    await journal.save(_entry('e1', 'First moment.'));
    await journal.save(_entry('e2', 'Second moment.'));

    final service = AccountDataPortabilityService(journalStore: journal);
    final result = await service.buildZipExport();

    expect(result.manifest.entryCount, 2);
    expect(result.zipBytes.length, greaterThan(128));
    expect(result.suggestedFileName, startsWith('archiveme-account-export-'));
  });
}