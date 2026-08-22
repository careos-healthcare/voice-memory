import 'dart:io';

import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/journal_entry/journal_entry_backlink_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 3),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('journal_entry_backlink_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('JournalEntryBacklinkService', () {
    test('builds quote highlights from fact ledger values in transcript', () async {
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final factStore = FactLedgerStore(prefs);
      final journalStore = await JournalStore.open('${tempDir.path}/journal.json');

      const entryId = 'entry_backlink_1';
      const transcript =
          'I keep avoiding hard conversations at work. It makes projects stall.';
      await journalStore.save(
        _entry(id: entryId, transcript: transcript),
      );
      await factStore.create(
        sourceEntryId: entryId,
        label: 'Avoidance',
        value: 'avoiding hard conversations at work',
        factType: FactType.other.id,
      );

      final snapshot = await JournalEntryBacklinkService.loadBacklinkSnapshot(
        entryId,
        journalStore: journalStore,
        factStore: factStore,
      );

      expect(snapshot.quoteHighlights, isNotEmpty);
      expect(
        snapshot.quoteHighlights.first.sentence.toLowerCase(),
        contains('avoiding hard conversations'),
      );
    });

    test('getDerivedInsights returns empty when archive lacks minimum evidence', () async {
      final journalStore = await JournalStore.open('${tempDir.path}/solo.json');
      await journalStore.save(
        _entry(
          id: 'solo_entry',
          transcript: 'Only one reflection so far in this archive test case.',
        ),
      );

      final insights = await JournalEntryBacklinkService.getDerivedInsights(
        'solo_entry',
        journalStore: journalStore,
      );

      expect(insights, isEmpty);
    });
  });
}