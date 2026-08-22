import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/discover/discover_engine.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_store.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One active surfaced insight for the transparency screen.
class SurfacedInsightRecord {
  const SurfacedInsightRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.confidenceBand,
    required this.sourceCount,
  });

  final String id;
  final ArchiveInsightKind kind;
  final String title;
  final PatternMatchConfidenceBand confidenceBand;
  final int sourceCount;
}

/// Builds the list of active surfaced insights from local synthesis.
class MemoryTransparencyCatalog {
  const MemoryTransparencyCatalog({
    this.discoverEngine = const DiscoverYourselfEngine(),
  });

  final DiscoverYourselfEngine discoverEngine;

  List<SurfacedInsightRecord> build({
    required List<JournalEntry> entries,
  }) {
    final snapshot = discoverEngine.build(entries: entries, useCache: false);
    final records = <SurfacedInsightRecord>[];

    final belief = snapshot.belief;
    if (belief != null && belief.statement.trim().isNotEmpty) {
      records.add(
        SurfacedInsightRecord(
          id: ArchiveInsightRef.belief().id,
          kind: ArchiveInsightKind.belief,
          title: belief.statement,
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            belief.confidencePercent,
          ),
          sourceCount: belief.evidenceCount,
        ),
      );
    }

    for (var i = 0; i < snapshot.beliefChanges.length; i++) {
      final change = snapshot.beliefChanges[i];
      records.add(
        SurfacedInsightRecord(
          id: ArchiveInsightRef.beliefChange(i).id,
          kind: ArchiveInsightKind.beliefChange,
          title: change.headline,
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            change.confidence,
          ),
          sourceCount: change.evidenceEntryIds.length,
        ),
      );
    }

    for (final theme in snapshot.themes) {
      records.add(
        SurfacedInsightRecord(
          id: ArchiveInsightRef.theme(theme.themeKey).id,
          kind: ArchiveInsightKind.theme,
          title: theme.name,
          confidenceBand: EvidenceProofCalculator.resolveBand(
            citationCount: theme.frequency,
          ),
          sourceCount: theme.frequency,
        ),
      );
    }

    for (final contradiction in snapshot.contradictions) {
      records.add(
        SurfacedInsightRecord(
          id: ArchiveInsightRef.contradiction(
            entryIdA: contradiction.entryIdA,
            entryIdB: contradiction.entryIdB,
          ).id,
          kind: ArchiveInsightKind.contradiction,
          title: contradiction.statementA,
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            contradiction.confidenceScore,
          ),
          sourceCount: 2,
        ),
      );
    }

    for (final spot in snapshot.blindSpots) {
      records.add(
        SurfacedInsightRecord(
          id: ArchiveInsightRef.blindSpot(spot.id).id,
          kind: ArchiveInsightKind.blindSpot,
          title: spot.headline,
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            spot.confidence,
          ),
          sourceCount: spot.evidenceCount,
        ),
      );
    }

    return [
      for (final record in records)
        if (!MemoryTransparencyStore.isSuppressed(record.id)) record,
    ];
  }
}

/// Returns true when synthesis should skip a surfaced insight.
bool archiveInsightSuppressed(ArchiveInsightRef ref) =>
    MemoryTransparencyStore.isSuppressed(ref.id);

bool archiveInsightSuppressedById(String insightId) =>
    MemoryTransparencyStore.isSuppressed(insightId);
