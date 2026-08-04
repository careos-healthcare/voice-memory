import '../models/archive_moment_record.dart';

/// Prunes a list of historical moments to protect the context window.
///
/// Keeps the most recent [maxContextItems] entries to maintain focus and
/// control token costs.
List<ArchiveMomentRecord> pruneHistoricalContext(
  List<ArchiveMomentRecord> history, {
  int maxContextItems = 30,
}) {
  RangeError.checkNotNegative(maxContextItems, 'maxContextItems');
  if (maxContextItems == 0) return <ArchiveMomentRecord>[];

  // Always return a new list so callers cannot mutate the source history
  // through the pruned result.
  if (history.length <= maxContextItems) {
    return List<ArchiveMomentRecord>.of(history);
  }

  // Track source positions to make equal timestamps deterministic. Sorting
  // once in chronological order avoids the descending-list/reverse copies.
  final chronological = history.indexed.toList()
    ..sort((a, b) {
      final dateOrder = a.$2.createdAt.compareTo(b.$2.createdAt);
      return dateOrder != 0 ? dateOrder : a.$1.compareTo(b.$1);
    });

  final firstRetainedIndex = chronological.length - maxContextItems;
  return [
    for (var i = firstRetainedIndex; i < chronological.length; i++)
      chronological[i].$2,
  ];
}
