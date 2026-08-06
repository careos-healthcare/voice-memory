/// Safe helpers for journal entry id lists attached to archive evidence.
abstract final class EvidenceEntryIds {
  EvidenceEntryIds._();

  /// Normalizes a single persisted entry id — never throws on legacy shapes.
  static String? normalize(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Merges id groups in order, de-duplicates, skips blanks/non-strings, caps length.
  static List<String> merge(Iterable<Iterable<Object?>> groups, {int max = 4}) {
    if (max <= 0) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final group in groups) {
      for (final raw in group) {
        final id = normalize(raw);
        if (id == null || !seen.add(id)) continue;
        out.add(id);
        if (out.length >= max) return List<String>.unmodifiable(out);
      }
    }
    return List<String>.unmodifiable(out);
  }
}
