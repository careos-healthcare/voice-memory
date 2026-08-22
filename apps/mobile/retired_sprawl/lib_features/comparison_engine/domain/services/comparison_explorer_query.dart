import 'package:archiveme_mobile/features/comparison_engine/domain/mappers/archive_moment_record_mapper.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Result of filtering on-device journal moments for a temporal comparison.
class ComparisonExplorerSnapshot {
  const ComparisonExplorerSnapshot({
    required this.window,
    required this.windowStart,
    required this.moments,
    required this.current,
    required this.historical,
  });

  final ComparisonTemporalWindow window;
  final DateTime? windowStart;
  final List<ArchiveMomentRecord> moments;
  final ArchiveMomentRecord? current;
  final List<ArchiveMomentRecord> historical;

  int get momentCount => moments.length;

  bool get hasEnoughForComparison => moments.length >= 2;

  bool get hasHistoricalContext => historical.isNotEmpty;
}

/// Filters locally stored journal entries into a chronological comparison snapshot.
abstract final class ComparisonExplorerQuery {
  ComparisonExplorerQuery._();

  static ComparisonExplorerSnapshot fromJournalEntries({
    required List<JournalEntry> entries,
    required ComparisonTemporalWindow window,
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final windowStart = window.windowStart(now: anchor);

    final moments = ArchiveMomentRecordMapper.fromJournalEntries(entries)
        .where((moment) => moment.savedWords.trim().isNotEmpty)
        .where(
          (moment) =>
              windowStart == null || !moment.createdAt.isBefore(windowStart),
        )
        .toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (moments.isEmpty) {
      return ComparisonExplorerSnapshot(
        window: window,
        windowStart: windowStart,
        moments: const [],
        current: null,
        historical: const [],
      );
    }

    if (moments.length == 1) {
      return ComparisonExplorerSnapshot(
        window: window,
        windowStart: windowStart,
        moments: moments,
        current: moments.single,
        historical: const [],
      );
    }

    final current = moments.last;
    final historical = moments.sublist(0, moments.length - 1);

    return ComparisonExplorerSnapshot(
      window: window,
      windowStart: windowStart,
      moments: moments,
      current: current,
      historical: historical,
    );
  }
}