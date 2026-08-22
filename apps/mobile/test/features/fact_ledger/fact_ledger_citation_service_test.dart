import 'dart:io';

import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/insights/archive_insight_mapper.dart';
import 'package:archiveme_mobile/features/insights/predictions/prediction_models.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_sqlite_repository.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/insights/insight_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 3, 1),
    transcript: transcript,
    durationSeconds: 20,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const ['work'],
      exactLanguagePattern: transcript,
      concreteObservation: transcript,
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    FactLedgerCitationService.resetForTest();
    AppSqliteDatabase.resetForTest();
  });

  group('FactLedgerCitationService', () {
    test('indexes and resolves exact quote from sqlite fact_ledger', () async {
      final db = await openTestAppSqliteDatabase();
      final repository = FactLedgerSqliteRepository(db);
      final tempDir = await Directory.systemTemp.createTemp('cite_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final store = FactLedgerStore(prefs);

      const exact = 'I said yes again before checking my calendar.';
      final entry = _entry(id: 'entry_1', transcript: exact);

      await FactLedgerCitationService.indexEntry(
        entry,
        store: store,
        repository: repository,
      );

      FactLedgerCitationService.resetForTest();
      await FactLedgerCitationService.warmCache(
        store: store,
        repository: repository,
      );

      expect(
        FactLedgerCitationService.resolve(
          entryId: entry.id,
          fallback: exact,
        ),
        exact,
      );

      final citations = await repository.loadEvidenceCitations();
      expect(citations, isNotEmpty);
      expect(citations.first.factType, FactType.evidenceCitation.id);
      expect(citations.first.value, exact);
    });

    test('indexes insight evidence lines with stable ids', () async {
      final tempDir = await Directory.systemTemp.createTemp('cite_lines_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final store = FactLedgerStore(prefs);

      const quote = 'The same thread keeps showing up at work.';
      await FactLedgerCitationService.indexEvidenceLines(
        [
          InsightEvidenceLine(
            entryId: 'entry_a',
            quote: quote,
            recordedAt: DateTime.utc(2026, 3, 2),
          ),
        ],
        provenance: 'insight:test',
        store: store,
      );

      expect(
        FactLedgerCitationService.resolve(
          entryId: 'entry_a',
          fallback: quote,
        ),
        quote,
      );

      final facts = await store.loadAll();
      expect(facts.single.id, FactLedgerCitationService.citationIdFor('entry_a', quote));
    });

    test('ArchiveInsightMapper.fromPrediction resolves ledger-backed quotes', () async {
      const triggerQuote = 'I keep saying yes at work.';
      const outcomeQuote = 'I felt drained after the meeting.';
      final tempDir = await Directory.systemTemp.createTemp('cite_mapper_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = FactLedgerStore(
        await MobilePrefsStore.open('${tempDir.path}/prefs.json'),
      );

      await FactLedgerCitationService.indexQuote(
        sourceEntryId: 'trigger_entry',
        quote: triggerQuote,
        provenance: 'test',
        store: store,
      );
      await FactLedgerCitationService.indexQuote(
        sourceEntryId: 'outcome_entry',
        quote: outcomeQuote,
        provenance: 'test',
        store: store,
      );

      final insight = ArchiveInsightMapper.fromPrediction(
        PredictionInsight(
          id: 'pred-1',
          title: 'Pattern may repeat',
          summary: 'Summary',
          confidence: 70,
          evidenceCount: 1,
          outcomeDescription: 'fatigue',
          supportingEvents: [
            PredictionEvent(
              triggerEntryId: 'trigger_entry',
              outcomeEntryId: 'outcome_entry',
              triggerQuote: triggerQuote,
              outcomeQuote: outcomeQuote,
              recordedAt: DateTime.utc(2026, 3, 3),
            ),
          ],
        ),
      );

      expect(
        insight.supportingEvidence.single.quote,
        '$triggerQuote → $outcomeQuote',
      );
    });
  });
}
