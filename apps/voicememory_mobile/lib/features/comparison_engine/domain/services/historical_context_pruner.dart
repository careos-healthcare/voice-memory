import '../models/archive_moment_record.dart';

/// Prunes a list of historical moments to protect the context window.
///
/// Keeps the most recent [maxContextItems] entries to maintain focus and
/// control token costs.
List<ArchiveMomentRecord> pruneHistoricalContext(
  List<ArchiveMomentRecord> history, {
  int maxContextItems = 30,
}) {
  if (history.length <= maxContextItems) return history;

  // Sort descending by creation date to get freshest context first.
  final sorted = List<ArchiveMomentRecord>.from(history)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Take the top N freshest items, then reverse back to chronological order.
  return sorted.take(maxContextItems).toList().reversed.toList();
}
