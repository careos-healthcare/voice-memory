import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_engine.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Commits extracted anchors to the local fact ledger.
abstract final class EvidenceIndexingService {
  EvidenceIndexingService._();

  static Future<bool> commitAnchor({
    required JournalEntry entry,
    required EvidenceIndexingChip chip,
    required FactLedgerStore store,
  }) async {
    final created = await store.create(
      sourceEntryId: entry.id,
      label: chip.label,
      value: chip.value,
      note: chip.category,
      factType: chip.factType,
      source: 'evidence_indexing',
    );
    return created != null;
  }

  static Future<int> commitAnchors({
    required JournalEntry entry,
    required List<EvidenceIndexingChip> chips,
    required FactLedgerStore store,
  }) async {
    var committed = 0;
    for (final chip in chips) {
      if (await commitAnchor(entry: entry, chip: chip, store: store)) {
        committed++;
      }
    }
    return committed;
  }

  static EvidenceTrailPayload trailPayloadForEntry(JournalEntry entry) {
    final chips = EvidenceIndexingEngine.extract(entry);
    final sources = [
      for (final chip in chips)
        EvidenceTrailSource(
          entryId: entry.id,
          recordedAt: entry.createdAt,
          excerpt: '"${chip.value}"',
        ),
    ];

    if (sources.isEmpty) {
      final transcript = entry.transcript.trim();
      if (transcript.isNotEmpty) {
        sources.add(
          EvidenceTrailSource(
            entryId: entry.id,
            recordedAt: entry.createdAt,
            excerpt: transcript.length > 160
                ? '"${transcript.substring(0, 160).trim()}…"'
                : '"$transcript"',
          ),
        );
      }
    }

    return EvidenceTrailPayload(
      title: 'Saved moment',
      whySummary:
          'These citable anchors were indexed from your latest recording.',
      evidenceCount: sources.length,
      sources: sources,
    );
  }
}