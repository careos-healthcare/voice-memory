/// Reciprocal Rank Fusion (RRF) for merging ranked result lists.
///
/// Standard formula: score(id) = sum(1 / (k + rank)) across lists, where rank
/// is 1-based.
class ReciprocalRankFusion {
  const ReciprocalRankFusion({this.k = 60});

  final int k;

  /// Merges [rankedEntryIds] (each inner list is best-first) into a single
  /// ranking ordered by descending fused score.
  List<String> fuse(
    List<List<String>> rankedEntryIds, {
    int limit = 20,
  }) {
    final scores = <String, double>{};

    for (final list in rankedEntryIds) {
      for (var index = 0; index < list.length; index++) {
        final entryId = list[index];
        if (entryId.isEmpty) continue;
        scores[entryId] = (scores[entryId] ?? 0) + 1 / (k + index + 1);
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        return a.key.compareTo(b.key);
      });

    return ranked.take(limit).map((entry) => entry.key).toList(growable: false);
  }
}
