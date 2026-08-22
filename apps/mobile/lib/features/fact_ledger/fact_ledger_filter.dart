import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';

/// Local search and filter helpers for saved details.
///
/// Query text stays in widget state only — never logged or persisted.
abstract class FactLedgerFilter {
  FactLedgerFilter._();

  static List<ArchiveFact> search(
    List<ArchiveFact> facts,
    String keyword, {
    String? factTypeId,
    String? packId,
  }) {
    var results = [...facts];
    if (packId != null) {
      results = results.where((f) => f.archivePackId == packId).toList();
    }
    if (factTypeId != null) {
      results = results.where((f) => f.factType == factTypeId).toList();
    }
    final term = keyword.trim().toLowerCase();
    if (term.isEmpty) {
      return _sorted(results);
    }
    return _sorted(
      results
          .where(
            (fact) =>
                fact.label.toLowerCase().contains(term) ||
                fact.value.toLowerCase().contains(term) ||
                fact.note.toLowerCase().contains(term),
          )
          .toList(),
    );
  }

  static Set<String> entryIdsWithFacts(List<ArchiveFact> facts) => {
    for (final fact in facts) fact.sourceEntryId,
  };

  static List<ArchiveFact> forEntry(
    String sourceEntryId,
    List<ArchiveFact> facts,
  ) => facts.where((f) => f.sourceEntryId == sourceEntryId).toList();

  static List<ArchiveFact> forPack(String packId, List<ArchiveFact> facts) =>
      facts.where((f) => f.archivePackId == packId).toList();

  static bool entryHasSavedDetail(String entryId, List<ArchiveFact> facts) =>
      facts.any((f) => f.sourceEntryId == entryId);

  static List<ArchiveFact> exportableFacts(
    List<ArchiveFact> facts, {
    Iterable<String>? selectedIds,
    String? packId,
  }) {
    final selected = selectedIds?.toSet();
    return facts
        .where(
          (fact) =>
              (selected == null || selected.contains(fact.id)) &&
              (packId == null || fact.archivePackId == packId),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static List<ArchiveFact> _sorted(List<ArchiveFact> facts) {
    final copy = [...facts];
    copy.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return copy;
  }
}