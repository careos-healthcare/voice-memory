import 'package:archiveme_mobile/features/archive_home/evidence_ledger_models.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Builds inspect-sheet rows from the archive V1 view.
abstract final class EvidenceLedgerInspectBuilder {
  EvidenceLedgerInspectBuilder._();

  static Future<List<EvidenceLedgerInspectItem>> buildFromEntries(
    List<JournalEntry> entries, {
    BeliefEvolutionService? evolutionService,
  }) async {
    if (entries.isEmpty) return const [];

    final view = await const ArchiveV1Builder().build(
      entries: entries,
      evolutionService:
          evolutionService ?? AppServices.instance.beliefEvolution,
    );
    return buildFromView(view, entries: entries);
  }

  static List<EvidenceLedgerInspectItem> buildFromView(
    ArchiveV1View view, {
    required List<JournalEntry> entries,
  }) {
    final byId = {for (final entry in entries) entry.id: entry};
    final items = <EvidenceLedgerInspectItem>[];

    final belief = view.belief;
    if (belief != null && belief.statement.trim().isNotEmpty) {
      items.add(
        EvidenceLedgerInspectItem(
          id: 'belief_primary',
          kind: EvidenceLedgerItemKind.belief,
          title: belief.statement.trim(),
          subtitle:
              '${belief.evidenceCount} supporting ${belief.evidenceCount == 1 ? 'entry' : 'entries'}',
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            belief.confidencePercent,
          ),
          referenceDate: belief.lastUpdated ??
              _latestEntryDate(belief.supportingEntries.map((e) => e.id), byId),
        ),
      );
    }

    for (final contradiction in view.contradictions) {
      items.add(
        EvidenceLedgerInspectItem(
          id: contradiction.id,
          kind: EvidenceLedgerItemKind.contradiction,
          title: contradiction.youSay.trim(),
          subtitle: contradiction.but.trim(),
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            contradiction.confidenceScore,
          ),
          referenceDate: _latestEntryDate(contradiction.entryIds, byId),
        ),
      );
    }

    for (final spot in view.blindSpots) {
      items.add(
        EvidenceLedgerInspectItem(
          id: spot.id,
          kind: EvidenceLedgerItemKind.blindSpot,
          title: spot.headline.trim(),
          subtitle: spot.observation.trim(),
          confidenceBand: EvidenceProofCalculator.bandFromConfidencePercent(
            spot.confidence,
          ),
          referenceDate: _latestEntryDate(spot.entryIds, byId),
        ),
      );
    }

    items.sort((a, b) {
      final bandCompare =
          a.confidenceBand.ledgerSortRank.compareTo(b.confidenceBand.ledgerSortRank);
      if (bandCompare != 0) return bandCompare;
      final aDate = a.referenceDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.referenceDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  static DateTime? _latestEntryDate(
    Iterable<String> entryIds,
    Map<String, JournalEntry> byId,
  ) {
    DateTime? latest;
    for (final id in entryIds) {
      final entry = byId[id];
      if (entry == null) continue;
      final created = entry.createdAt;
      if (latest == null || created.isAfter(latest)) {
        latest = created;
      }
    }
    return latest;
  }
}

/// Filters inspect rows by keyword and optional date window.
abstract final class EvidenceLedgerInspectFilter {
  EvidenceLedgerInspectFilter._();

  static List<EvidenceLedgerInspectItem> apply({
    required List<EvidenceLedgerInspectItem> items,
    required String query,
    required EvidenceLedgerDateFilter dateFilter,
    DateTime? now,
  }) {
    final trimmedQuery = query.trim().toLowerCase();
    final anchor = now ?? DateTime.now();
    final minDate = _minimumDate(dateFilter, anchor);

    return [
      for (final item in items)
        if (_matchesQuery(item, trimmedQuery) && _matchesDate(item, minDate))
          item,
    ];
  }

  static DateTime? _minimumDate(
    EvidenceLedgerDateFilter filter,
    DateTime anchor,
  ) {
    return switch (filter) {
      EvidenceLedgerDateFilter.all => null,
      EvidenceLedgerDateFilter.last7Days => anchor.subtract(const Duration(days: 7)),
      EvidenceLedgerDateFilter.last30Days =>
        anchor.subtract(const Duration(days: 30)),
      EvidenceLedgerDateFilter.last90Days =>
        anchor.subtract(const Duration(days: 90)),
    };
  }

  static bool _matchesQuery(EvidenceLedgerInspectItem item, String query) {
    if (query.isEmpty) return true;
    return item.searchableText.toLowerCase().contains(query);
  }

  static bool _matchesDate(
    EvidenceLedgerInspectItem item,
    DateTime? minimumDate,
  ) {
    if (minimumDate == null) return true;
    final reference = item.referenceDate;
    if (reference == null) return false;
    return !reference.isBefore(minimumDate);
  }
}